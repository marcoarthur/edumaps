package EduMaps::Roles::Business::Canal::Segmentos;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(true false encode_json decode_json);

# ============================================================================
# LISTAS DINÂMICAS (SEGMENTOS) E RESOLUÇÃO DE MEMBROS (issue #216 — Fase 3)
# ============================================================================
#
# Um segmento é uma regra salva sobre os membros das listas da PRÓPRIA escola
# (RF-305), resolvida na hora do envio. Critérios (contrato da onda 1):
#
#   listas            1..50 ids de listas da escola (união). Id que não é
#                     lista da escola → inválido (400). Lista excluída
#                     (desativada) DEPOIS é ignorada e aparece em
#                     `listas_ignoradas` na prévia;
#   estado            ⊆ {pendente, parcial, confirmado, nao_exigida}: estado
#                     geral do membro NAQUELA lista (mesma regra de
#                     `estado_contatos`); vazio/ausente = todos;
#   email_confirmado  true → e-mail confirmado; false → não confirmado;
#                     null/ausente → indiferente;
#   inscritos_desde/  datas YYYY-MM-DD inclusivas sobre a entrada do membro
#   inscritos_ate     na lista (canal_lista_membros.created_at, fuso
#                     America/Sao_Paulo); desde ≤ ate.
#
# Também concentra a resolução de membros com e-mail usada pelos envios
# (`resolver_destinatarios`): e-mail do CONTATO (clean.contatos.email)
# normalizado lower(trim()), hash sha256 no banco (pgcrypto), opt-out por
# lista e dedupe por e-mail.
#
# Composta no model Canal; usa os helpers SQL de Canal::Listas.

requires qw(schema _rows _row estado_contatos _sql_estado_membro);

our @ESTADOS_SEGMENTO = qw(pendente parcial confirmado nao_exigida);
our $SEGMENTO_MAX_LISTAS = 50;
our $AMOSTRA_MAX = 10;

my $ISO = q{to_char(%s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')};

# ---------------------------------------------------------------------------
# máscara de e-mail (prévias e destinatários)
# ---------------------------------------------------------------------------

# `joana@dominio.com.br` → `j***@d***.br`. undef/vazio → undef.
sub mascarar_email ($self, $email) {
  return undef unless defined $email && length $email;
  my ($user, $dom) = split /\@/, $email, 2;
  return '***' unless defined $dom && length $dom;
  my @partes = split /\./, $dom;
  my $tld = @partes > 1 ? '.' . $partes[-1] : '';
  return substr($user, 0, 1) . '***@' . substr($dom, 0, 1) . "***$tld";
}

# ---------------------------------------------------------------------------
# critérios
# ---------------------------------------------------------------------------

# Valida e normaliza os critérios. Devolve { ok => 1, criterios => {...} } ou
# { error => <mensagem> } (400).
sub segmento_validar_criterios ($self, $cod_inep, $c) {
  return { error => 'criterios deve ser um objeto.' } unless ref $c eq 'HASH';

  my $listas = $c->{listas};
  return { error => "criterios.listas deve ter de 1 a $SEGMENTO_MAX_LISTAS listas." }
    unless ref $listas eq 'ARRAY' && @$listas >= 1 && @$listas <= $SEGMENTO_MAX_LISTAS;
  my %vistos;
  my @ids;
  for my $id (@$listas) {
    return { error => 'criterios.listas deve conter apenas ids inteiros.' }
      unless defined $id && !ref $id && $id =~ /^\d{1,18}\z/;
    push @ids, $id + 0 unless $vistos{ $id + 0 }++;
  }
  my $da_escola = $self->_rows(
    q{SELECT id FROM clean.canal_listas WHERE cod_inep = ? AND id = ANY(?::bigint[])},
    $cod_inep + 0, \@ids,
  );
  return { error => 'criterios.listas contém lista que não é desta escola.' }
    unless @$da_escola == @ids;

  my $estado = $c->{estado} // [];
  return { error => 'criterios.estado deve ser uma lista.' } unless ref $estado eq 'ARRAY';
  my %ok = map { $_ => 1 } @ESTADOS_SEGMENTO;
  my %ve;
  for my $e (@$estado) {
    return { error => 'criterios.estado inválido (pendente, parcial, confirmado, nao_exigida).' }
      unless defined $e && !ref $e && $ok{$e};
  }
  my @estado = grep { !$ve{$_}++ } @$estado;

  my $ec = $c->{email_confirmado};
  if (defined $ec) {
    my $b = $self->parse_bool($ec);
    return { error => 'criterios.email_confirmado deve ser true, false ou null.' }
      unless defined $b;
    $ec = $b ? true : false;
  }

  my %datas;
  for my $k (qw(inscritos_desde inscritos_ate)) {
    my $v = $c->{$k};
    $v = undef if defined $v && !ref $v && $v eq '';
    if (defined $v) {
      return { error => "criterios.$k deve ser uma data YYYY-MM-DD." }
        unless !ref $v && $v =~ /^\d{4}-\d\d-\d\d\z/
            && eval { $self->_row(q{SELECT ?::date AS d}, $v) };
    }
    $datas{$k} = $v;
  }
  return { error => 'criterios.inscritos_desde deve ser anterior ou igual a inscritos_ate.' }
    if defined $datas{inscritos_desde} && defined $datas{inscritos_ate}
    && $datas{inscritos_desde} gt $datas{inscritos_ate};

  return { ok => 1, criterios => {
    listas           => \@ids,
    estado           => \@estado,
    email_confirmado => $ec,
    %datas,
  } };
}

# ---------------------------------------------------------------------------
# CRUD
# ---------------------------------------------------------------------------

sub segmentos_listar ($self, $cod_inep) {
  my $rows = $self->_rows(
    sprintf(q{SELECT id, nome, criterios::text AS criterios,
                     %s AS created_at, %s AS updated_at
              FROM   clean.canal_segmentos
              WHERE  cod_inep = ?
              ORDER  BY nome, id}, sprintf($ISO, 'created_at'), sprintf($ISO, 'updated_at')),
    $cod_inep + 0,
  );
  return [ map { $self->_segmento_publico($cod_inep, $_) } @$rows ];
}

sub segmento_detalhe ($self, $cod_inep, $id) {
  my $r = $self->_segmento_row($cod_inep, $id) or return;
  return $self->_segmento_publico($cod_inep, $r);
}

# Cria. Devolve o segmento ou { error, status => 400|409 }.
sub segmento_criar ($self, %p) {
  my ($cod_inep, $gestor_id) = @p{qw(cod_inep gestor_id)};
  my $nome = $self->_segmento_nome($p{nome});
  return { error => 'nome é obrigatório (1..120 caracteres).', status => 400 }
    unless defined $nome;
  my $v = $self->segmento_validar_criterios($cod_inep, $p{criterios});
  return { error => $v->{error}, status => 400 } if $v->{error};

  my $row = eval {
    $self->_row(
      q{INSERT INTO clean.canal_segmentos (cod_inep, gestor_id, nome, criterios)
        VALUES (?, ?, ?, ?::jsonb)
        ON CONFLICT (cod_inep, nome) DO NOTHING
        RETURNING id},
      $cod_inep + 0, $gestor_id + 0, $nome, encode_json($v->{criterios}),
    );
  };
  return { error => 'Já existe uma lista dinâmica com este nome nesta escola.', status => 409 }
    unless $row;
  return $self->segmento_detalhe($cod_inep, $row->{id});
}

# Edita (PUT: nome + criterios). Devolve o segmento, undef (não é da escola)
# ou { error, status => 400|409 }.
sub segmento_atualizar ($self, $cod_inep, $id, %p) {
  $self->_segmento_row($cod_inep, $id) or return;
  my $nome = $self->_segmento_nome($p{nome});
  return { error => 'nome é obrigatório (1..120 caracteres).', status => 400 }
    unless defined $nome;
  my $v = $self->segmento_validar_criterios($cod_inep, $p{criterios});
  return { error => $v->{error}, status => 400 } if $v->{error};

  my $dup = $self->_row(
    'SELECT 1 AS x FROM clean.canal_segmentos WHERE cod_inep = ? AND nome = ? AND id <> ?',
    $cod_inep + 0, $nome, $id + 0,
  );
  return { error => 'Já existe uma lista dinâmica com este nome nesta escola.', status => 409 }
    if $dup;

  my $ok = eval {
    $self->_rows(
      q{UPDATE clean.canal_segmentos
           SET nome = ?, criterios = ?::jsonb, gestor_id = COALESCE(?, gestor_id),
               updated_at = NOW()
         WHERE id = ? AND cod_inep = ?},
      $nome, encode_json($v->{criterios}), $p{gestor_id}, $id + 0, $cod_inep + 0,
    );
    1;
  };
  return { error => 'Já existe uma lista dinâmica com este nome nesta escola.', status => 409 }
    unless $ok;
  return $self->segmento_detalhe($cod_inep, $id);
}

# Apaga. Devolve { ok => 1 } ou undef (não é da escola). Envios que o usavam
# como alvo guardam a fotografia do nome (alvo_nome).
sub segmento_apagar ($self, $cod_inep, $id) {
  my $r = $self->_row(
    'DELETE FROM clean.canal_segmentos WHERE id = ? AND cod_inep = ? RETURNING id',
    $id + 0, $cod_inep + 0,
  ) or return;
  return { ok => 1 };
}

# ---------------------------------------------------------------------------
# prévia
# ---------------------------------------------------------------------------

# Prévia de critérios (salvos ou não): { destinatarios, amostra: [{nome,
# email}], listas_ignoradas: [ids] } ou { error } (critérios inválidos).
# `destinatarios` = endereços únicos que receberiam (sem opt-outs); amostra de
# até 10, por nome, com e-mail mascarado.
sub segmento_previa ($self, $cod_inep, $criterios) {
  my $v = $self->segmento_validar_criterios($cod_inep, $criterios);
  return { error => $v->{error} } if $v->{error};
  my $c = $v->{criterios};

  my %ativas = map { $_ => 1 } @{ $self->_listas_ativas($cod_inep, $c->{listas}) };
  my $r = $self->resolver_destinatarios($cod_inep, [ grep { $ativas{$_} } @{ $c->{listas} } ], $c);
  my @validos = sort { lc($a->{nome} // '') cmp lc($b->{nome} // '') || $a->{email} cmp $b->{email} }
                grep { !$_->{optout} } @{ $r->{itens} };
  my $n = @validos;
  $#validos = $AMOSTRA_MAX - 1 if @validos > $AMOSTRA_MAX;
  return {
    destinatarios    => $n,
    amostra          => [ map { +{ nome => $_->{nome}, email => $self->mascarar_email($_->{email}) } } @validos ],
    listas_ignoradas => [ grep { !$ativas{$_} } @{ $c->{listas} } ],
  };
}

# Prévia de um segmento salvo; undef se não é da escola.
sub segmento_previa_salvo ($self, $cod_inep, $id) {
  my $s = $self->_segmento_row($cod_inep, $id) or return;
  my $c = decode_json($s->{criterios});
  # listas da escola que já não existem fisicamente saem da validação (seriam
  # 400); viram `listas_ignoradas`.
  my %existe = map { $_->{id} => 1 } @{ $self->_rows(
    q{SELECT id FROM clean.canal_listas WHERE cod_inep = ? AND id = ANY(?::bigint[])},
    $cod_inep + 0, [ map { $_ + 0 } @{ $c->{listas} // [] } ],
  ) };
  my @sumidas = grep { !$existe{$_} } @{ $c->{listas} // [] };
  my @ficam   = grep { $existe{$_} } @{ $c->{listas} // [] };
  if (!@ficam) {
    return { destinatarios => 0, amostra => [], listas_ignoradas => [ map { $_ + 0 } @sumidas ] };
  }
  my $p = $self->segmento_previa($cod_inep, { %$c, listas => \@ficam });
  return $p if $p->{error};
  push @{ $p->{listas_ignoradas} }, map { $_ + 0 } @sumidas;
  return $p;
}

# ---------------------------------------------------------------------------
# resolução de membros com e-mail (segmentos e envios)
# ---------------------------------------------------------------------------

# Membros com e-mail das listas `$lista_ids` (só listas ATIVAS da escola),
# filtrados por `$filtro` (critérios do segmento; undef = todos). Agrupa por
# e-mail normalizado (dedupe):
#
#   - optout: o endereço saiu de ALGUMA lista do alvo em que é membro
#     (canal_optouts por lista + hash);
#   - lista_id: menor id entre as listas do alvo em que é membro e não saiu
#     (com opt-out: a menor lista de onde saiu);
#   - contato_id/nome: os do membro daquela lista.
#
# Devolve { itens => [{email, email_hash, contato_id, nome, lista_id,
# optout}], duplicados => <membros descartados por e-mail repetido> }.
sub resolver_destinatarios ($self, $cod_inep, $lista_ids, $filtro = undef) {
  my @ids = map { $_ + 0 } @{ $lista_ids // [] };
  return { itens => [], duplicados => 0 } unless @ids;

  my ($ultima, $tem_tel, $tem_email) = $self->_sql_estado_membro;
  my $rows = $self->_rows(
    qq{SELECT m.id AS membro_id, m.lista_id, m.contato_id, c.nome,
              lower(trim(c.email)) AS email,
              encode(digest(lower(trim(c.email)), 'sha256'), 'hex') AS email_hash,
              m.confirmado_em, m.confirmado_via,
              m.email_confirmado_em, m.email_confirmado_via,
              l.exige_confirmacao,
              $tem_tel AS tem_telefone, $tem_email AS tem_email,
              to_char((m.created_at AT TIME ZONE 'America/Sao_Paulo')::date, 'YYYY-MM-DD')
                AS inscrito_dia,
              EXISTS (SELECT 1 FROM clean.canal_optouts o
                       WHERE o.lista_id = m.lista_id AND o.canal = 'email'
                         AND o.email_hash = encode(digest(lower(trim(c.email)), 'sha256'), 'hex'))
                AS optout
       FROM   clean.canal_lista_membros m
       JOIN   clean.canal_listas l ON l.id = m.lista_id AND l.cod_inep = ? AND l.ativo
       JOIN   clean.contatos c     ON c.id = m.contato_id
       $ultima
       WHERE  m.lista_id = ANY(?::bigint[])
         AND  c.email IS NOT NULL AND trim(c.email) <> ''
       ORDER  BY m.lista_id, m.id},
    $cod_inep + 0, \@ids,
  );

  my (%por, @ordem);
  my $total = 0;
  for my $r (@$rows) {
    next if $filtro && !$self->_membro_passa($r, $filtro);
    $total++;
    my $g = $por{ $r->{email_hash} } //= do { push @ordem, $r->{email_hash}; { membros => [] } };
    push @{ $g->{membros} }, $r;
  }

  my @itens;
  for my $h (@ordem) {
    my @m = @{ $por{$h}{membros} };
    my @saiu = grep { $_->{optout} } @m;
    my @base = @saiu ? @saiu : @m;
    my ($origem) = sort { $a->{lista_id} <=> $b->{lista_id} || $a->{membro_id} <=> $b->{membro_id} } @base;
    push @itens, {
      email      => $origem->{email},
      email_hash => $h,
      contato_id => $origem->{contato_id} + 0,
      nome       => $origem->{nome},
      lista_id   => $origem->{lista_id} + 0,
      optout     => @saiu ? 1 : 0,
    };
  }
  return { itens => \@itens, duplicados => $total - @itens };
}

# O membro passa nos critérios do segmento?
sub _membro_passa ($self, $r, $f) {
  if ($f->{estado} && @{ $f->{estado} }) {
    my $ec = $self->estado_contatos(
      exige        => $r->{exige_confirmacao},
      tem_telefone => $r->{tem_telefone},
      tem_email    => $r->{tem_email},
      map { $_ => $r->{$_} }
        qw(confirmado_em confirmado_via email_confirmado_em email_confirmado_via),
    );
    return 0 unless grep { $_ eq $ec->{estado} } @{ $f->{estado} };
  }
  if (defined $f->{email_confirmado}) {
    my $quer = $f->{email_confirmado} ? 1 : 0;
    my $tem  = defined $r->{email_confirmado_em} ? 1 : 0;
    return 0 unless $quer == $tem;
  }
  return 0 if defined $f->{inscritos_desde} && $r->{inscrito_dia} lt $f->{inscritos_desde};
  return 0 if defined $f->{inscritos_ate}   && $r->{inscrito_dia} gt $f->{inscritos_ate};
  return 1;
}

# Ids (dentre `$ids`) de listas ATIVAS da escola.
sub _listas_ativas ($self, $cod_inep, $ids) {
  return [ map { $_->{id} + 0 } @{ $self->_rows(
    q{SELECT id FROM clean.canal_listas
       WHERE cod_inep = ? AND ativo AND id = ANY(?::bigint[]) ORDER BY id},
    $cod_inep + 0, [ map { $_ + 0 } @$ids ],
  ) } ];
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _segmento_nome ($self, $nome) {
  return undef unless defined $nome && !ref $nome;
  $nome =~ s/^\s+|\s+$//g;
  return length $nome >= 1 && length $nome <= 120 ? $nome : undef;
}

sub _segmento_row ($self, $cod_inep, $id) {
  return unless defined $id && $id =~ /^\d+\z/;
  return $self->_row(
    sprintf(q{SELECT id, nome, criterios::text AS criterios,
                     %s AS created_at, %s AS updated_at
              FROM   clean.canal_segmentos
              WHERE  id = ? AND cod_inep = ?}, sprintf($ISO, 'created_at'), sprintf($ISO, 'updated_at')),
    $id + 0, $cod_inep + 0,
  );
}

# Formato do contrato: { id, nome, criterios, listas: [{id, nome, existe}],
# created_at, updated_at }. `existe` = lista ativa da escola.
sub _segmento_publico ($self, $cod_inep, $r) {
  my $c = decode_json($r->{criterios});
  my @ids = map { $_ + 0 } @{ $c->{listas} // [] };
  my %l = map { $_->{id} => $_ } @{ $self->_rows(
    q{SELECT id, nome, ativo FROM clean.canal_listas
       WHERE cod_inep = ? AND id = ANY(?::bigint[])},
    $cod_inep + 0, \@ids,
  ) };
  return {
    id        => $r->{id} + 0,
    nome      => $r->{nome},
    criterios => {
      listas           => \@ids,
      estado           => $c->{estado} // [],
      email_confirmado => defined $c->{email_confirmado}
                            ? ($c->{email_confirmado} ? true : false) : undef,
      inscritos_desde  => $c->{inscritos_desde},
      inscritos_ate    => $c->{inscritos_ate},
    },
    listas => [ map {
      my $x = $l{$_};
      my $ok = $x && $x->{ativo};
      +{ id => $_, nome => $ok ? $x->{nome} : undef, existe => $ok ? true : false };
    } @ids ],
    created_at => $r->{created_at},
    updated_at => $r->{updated_at},
  };
}

1;
