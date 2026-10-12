package EduMaps::Roles::Business::Canal::Exclusao;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(sha256_hex);
use Mojo::JSON qw(true false);

# ============================================================================
# EXCLUSÃO E RETENÇÃO DOS DADOS DAS LISTAS (issue #214 — Fase 2, RF-204..207)
# ============================================================================
#
# Anonimização (`anonimizar_contato`, RF-206) — conforme o inventário de PII
# da spec, numa transação e de forma idempotente:
#
#   clean.contatos            nome '[removido]', telefone/e-mail NULL;
#   clean.canal_inscricoes    do contato: nome '[removido]', telefone,
#                             telefone_norm, email, email_norm, ip_anon,
#                             user_agent NULL + anonimizado_em. Em inscrições
#                             de OUTROS contatos da escola (conflito), o
#                             telefone/e-mail do titular também sai;
#   canal_lista_membros       linhas do contato removidas de TODAS as listas
#                             da escola (a pessoa sai da escola);
#   canal_confirmacao_refs    invalidadas, telegram_chat_pendente NULL (as do
#                             membro caem em cascata com ele);
#   canal_confirmacoes        do contato ou dos endereços dele: pendentes
#                             expiradas e `endereco` trocado por
#                             'sha256:<hex>';
#   canal_mensagens           do contato (contato_id, endereços, refs e
#                             códigos dele): destinatário '[removido]', corpo
#                             e erro NULL;
#   canal_exclusoes           registro SEM PII (origem, regra, gestor, motivo,
#                             contagens).
#
# O contato NÃO é apagado (reuniões/relações continuam, anonimizadas): uma
# nova inscrição da mesma pessoa cria um contato novo (o dedupe procura por
# telefone/e-mail, que ficaram NULL).
#
# Retenção (RF-207) — três regras, cada uma na sua transação, com uma linha
# de resumo em canal_exclusoes (origem 'retencao', cod_inep 0 = instalação)
# MESMO com contagem zero, mais uma linha por escola afetada (histórico do
# gestor):
#
#   metadados       ip_anon/user_agent NULL nas inscrições mais antigas que
#                   `metadados_dias` (conta inscrições);
#   pendentes       anonimiza inscritos nunca confirmados (nenhum contato
#                   confirmado em nenhuma lista) de listas que exigem
#                   confirmação, sem inscrição mais nova que
#                   `pendentes_dias`;
#   lista_inativa   anonimiza membros de listas desativadas
#                   (`desativada_em`) há mais de `listas_inativas_meses`,
#                   exceto quem está em outra lista ATIVA da escola.
#
# Nas duas regras que anonimizam, só entram contatos NASCIDOS da
# autoinscrição (a primeira inscrição criou o contato): contato que já
# existia na agenda do gestor não é anonimizado pela retenção.
#
# Composta no model Canal; usa os helpers SQL de Canal::Listas e a config de
# retenção do AppConfig.

requires qw(schema _rows _row retencao_config);

our $REMOVIDO = '[removido]';
our $HISTORICO_MAX = 200;

my $ISO = q{to_char(%s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')};

# Contato nascido da autoinscrição (alias do contato: %s).
my $SQL_NASCIDO_NA_INSCRICAO = q{EXISTS (
         SELECT 1 FROM (SELECT f.duplicado_de FROM clean.canal_inscricoes f
                         WHERE f.contato_id = %1$s ORDER BY f.id LIMIT 1) f1
          WHERE f1.duplicado_de IS NULL)};

# ---------------------------------------------------------------------------
# token de exclusão do titular (RF-204)
# ---------------------------------------------------------------------------

sub exclusao_token_valido ($self, $token) {
  return defined $token && !ref $token && $token =~ /^[0-9a-fA-F]{32}\z/ ? 1 : 0;
}

# Inscrição do token (só o sha256 está no banco). Devolve undef (formato
# inválido/inexistente) ou { inscricao_id, contato_id, lista_id, cod_inep,
# escola_nome, lista_nome, ja_excluido }.
sub exclusao_por_token ($self, $token) {
  return unless $self->exclusao_token_valido($token);
  my $r = $self->_row(
    q{SELECT i.id AS inscricao_id, i.contato_id, i.lista_id, i.anonimizado_em,
             l.cod_inep, l.nome AS lista_nome, e.escola AS escola_nome
      FROM   clean.canal_inscricoes i
      JOIN   clean.canal_listas l   ON l.id = i.lista_id
      LEFT JOIN clean.escolas e     ON e.codigo_inep = l.cod_inep
      WHERE  i.exclusao_hash = ?},
    sha256_hex(lc $token),
  ) or return;
  return {
    inscricao_id => $r->{inscricao_id} + 0,
    contato_id   => defined $r->{contato_id} ? $r->{contato_id} + 0 : undef,
    lista_id     => $r->{lista_id} + 0,
    cod_inep     => $r->{cod_inep} + 0,
    escola_nome  => $r->{escola_nome},
    lista_nome   => $r->{lista_nome},
    ja_excluido  => defined $r->{anonimizado_em} ? 1 : 0,
  };
}

# Exclusão pelo titular (POST com o token). Idempotente: inscrição já
# anonimizada → { ok => 1, ja_excluido => 1 } sem novo registro.
# Devolve undef se o token não existe.
sub excluir_por_token ($self, $token) {
  my $e = $self->exclusao_por_token($token) or return;
  return { ok => 1, ja_excluido => 1 } if $e->{ja_excluido};
  my $r = $self->anonimizar_contato(
    $e->{cod_inep}, $e->{contato_id},
    origem        => 'titular',
    inscricao_ids => [ $e->{inscricao_id} ],
  ) or return;
  return { %$r, ja_excluido => 0 };
}

# ---------------------------------------------------------------------------
# exclusão pelo gestor (RF-205) e histórico
# ---------------------------------------------------------------------------

# Remove (anonimiza) o contato do membro `membro_id` da lista `lista_id` da
# escola. Devolve undef se o membro não é daquela lista/escola.
sub excluir_membro ($self, $cod_inep, $lista_id, $membro_id, %p) {
  for ($cod_inep, $lista_id, $membro_id) {
    return unless defined $_ && !ref $_ && /^\d+\z/;
  }
  my $m = $self->_row(
    q{SELECT m.contato_id
      FROM   clean.canal_lista_membros m
      JOIN   clean.canal_listas l ON l.id = m.lista_id
      WHERE  m.id = ? AND m.lista_id = ? AND l.cod_inep = ?},
    $membro_id + 0, $lista_id + 0, $cod_inep + 0,
  ) or return;
  return $self->anonimizar_contato(
    $cod_inep, $m->{contato_id},
    origem    => 'gestor',
    gestor_id => $p{gestor_id},
    motivo    => $p{motivo},
  );
}

# Histórico de exclusões da escola (sem PII), mais recentes primeiro.
sub listar_exclusoes ($self, $cod_inep, $limite = $HISTORICO_MAX) {
  my $rows = $self->_rows(
    sprintf(q{SELECT id, origem, regra, motivo, gestor_id, contatos, inscricoes,
                     membros, %s AS created_at
              FROM   clean.canal_exclusoes
              WHERE  cod_inep = ?
              ORDER  BY created_at DESC, id DESC
              LIMIT  ?}, sprintf($ISO, 'created_at')),
    $cod_inep + 0, $limite + 0,
  );
  return [ map {
    +{
      id         => $_->{id} + 0,
      origem     => $_->{origem},
      regra      => $_->{regra},
      motivo     => $_->{motivo},
      gestor_id  => defined $_->{gestor_id} ? $_->{gestor_id} + 0 : undef,
      contatos   => $_->{contatos} + 0,
      inscricoes => $_->{inscricoes} + 0,
      membros    => $_->{membros} + 0,
      created_at => $_->{created_at},
    }
  } @$rows ];
}

# ---------------------------------------------------------------------------
# anonimização (RF-206)
# ---------------------------------------------------------------------------

# anonimizar_contato($cod_inep, $contato_id, origem => titular|gestor|retencao,
#   gestor_id?, motivo?, regra?, inscricao_ids? (inscrições extras — ex.: a do
#   token quando o contato já não existe), registrar? (default 1)).
#
# Numa transação. Devolve { ok => 1, contatos, inscricoes, membros,
# exclusao_id? } (contagens do que MUDOU: chamada repetida devolve zeros e não
# registra), ou undef se o contato não é da escola (e não há inscrição extra).
sub anonimizar_contato ($self, $cod_inep, $contato_id, %p) {
  my $origem = $p{origem} // '';
  die "anonimizar_contato: origem inválida '$origem'\n"
    unless $origem =~ /^(?:titular|gestor|retencao)\z/;

  my $res;
  $self->schema->storage->txn_do(sub {
    $res = $self->_anonimizar($cod_inep, $contato_id, %p) or return;
    my $mudou = $res->{contatos} || $res->{inscricoes} || $res->{membros};
    if ($mudou && ($p{registrar} // 1)) {
      $res->{exclusao_id} = $self->_registrar_exclusao(
        cod_inep => $cod_inep, origem => $origem, regra => $p{regra},
        gestor_id => $p{gestor_id}, motivo => $p{motivo},
        map { $_ => $res->{$_} } qw(contatos inscricoes membros),
      );
    }
  });
  return $res;
}

# Núcleo da anonimização — chamar DENTRO de uma transação.
sub _anonimizar ($self, $cod_inep, $contato_id, %p) {
  $cod_inep += 0;
  my @extra = grep { defined && /^\d+\z/ } @{ $p{inscricao_ids} // [] };

  my $c;
  if (defined $contato_id) {
    $c = $self->_row(
      q{SELECT id, telefone, email FROM clean.contatos
         WHERE id = ? AND cod_inep = ? FOR UPDATE},
      $contato_id + 0, $cod_inep,
    );
  }
  return unless $c || @extra;
  my $cid = $c ? $c->{id} + 0 : undef;

  # inscrições do titular na escola (do contato + extras)
  my $insc = $self->_rows(
    q{SELECT i.id, i.telefone_norm, i.email_norm
      FROM   clean.canal_inscricoes i
      JOIN   clean.canal_listas l ON l.id = i.lista_id
      WHERE  l.cod_inep = ? AND (i.contato_id = ? OR i.id = ANY(?::bigint[]))},
    $cod_inep, $cid, \@extra,
  );
  my @insc_ids = map { $_->{id} + 0 } @$insc;

  # endereços do titular (telefone em claro, normalizado e no formato do
  # WhatsApp; e-mail em minúsculas; chats do Telegram)
  my (%tel, %mail, %chat);
  for my $t (($c ? $c->{telefone} : ()), map { $_->{telefone_norm} } @$insc) {
    next unless defined $t && length $t;
    my $d = $t =~ s/\D//gr;
    next unless length $d;
    $tel{$d} = 1;
    (my $wa = $d) =~ s/^00//;
    $wa = "55$wa" unless $wa =~ /^55/ && length($wa) >= 12;
    $tel{$wa} = 1;
  }
  for my $e (($c ? $c->{email} : ()), map { $_->{email_norm} } @$insc) {
    next unless defined $e && length $e;
    $mail{lc $e} = 1;
  }

  my $membros = $cid ? $self->_rows(
    q{SELECT m.id, m.telegram_chat_id
      FROM   clean.canal_lista_membros m
      JOIN   clean.canal_listas l ON l.id = m.lista_id
      WHERE  m.contato_id = ? AND l.cod_inep = ?},
    $cid, $cod_inep,
  ) : [];
  my @membro_ids = map { $_->{id} + 0 } @$membros;
  $chat{ $_->{telegram_chat_id} } = 1 for grep { defined $_->{telegram_chat_id} } @$membros;

  my $refs = $self->_rows(
    q{SELECT id, telegram_chat_pendente FROM clean.canal_confirmacao_refs
       WHERE membro_id = ANY(?::bigint[]) OR inscricao_id = ANY(?::bigint[])},
    \@membro_ids, \@insc_ids,
  );
  my @ref_ids = map { $_->{id} + 0 } @$refs;
  $chat{ $_->{telegram_chat_pendente} } = 1
    for grep { defined $_->{telegram_chat_pendente} } @$refs;

  my @enderecos = (sort(keys %tel), sort(keys %mail), sort(keys %chat));

  # canal_confirmacoes: do contato ou dos endereços (na escola ou sem escola)
  my $conf_ids = [ map { $_->{id} + 0 } @{ $self->_rows(
    q{SELECT id FROM clean.canal_confirmacoes
       WHERE (contato_id IS NOT NULL AND contato_id = ?)
          OR ((cod_inep = ? OR cod_inep IS NULL) AND endereco = ANY(?::text[]))},
    $cid, $cod_inep, \@enderecos,
  ) } ];

  # canal_mensagens do titular: destinatário e corpo apagados
  $self->_exec(
    q{UPDATE clean.canal_mensagens
         SET destinatario = ?, corpo = NULL, erro = NULL
       WHERE (destinatario <> ? OR corpo IS NOT NULL OR erro IS NOT NULL)
         AND (   (contato_id IS NOT NULL AND contato_id = ?)
              OR ((cod_inep = ? OR cod_inep IS NULL) AND destinatario = ANY(?::text[]))
              OR (referente_tipo = 'confirmacao'     AND referente_id = ANY(?::bigint[]))
              OR (referente_tipo = 'confirmacao_ref' AND referente_id = ANY(?::bigint[])))},
    $REMOVIDO, $REMOVIDO, $cid, $cod_inep, \@enderecos, $conf_ids, \@ref_ids,
  );

  # códigos pendentes expirados; endereço trocado por hash
  $self->_exec(
    q{UPDATE clean.canal_confirmacoes SET expira_em = NOW()
       WHERE id = ANY(?::bigint[]) AND confirmado_em IS NULL AND expira_em > NOW()},
    $conf_ids,
  );
  $self->_exec(
    q{UPDATE clean.canal_confirmacoes
         SET endereco = 'sha256:' || encode(digest(endereco, 'sha256'), 'hex')
       WHERE id = ANY(?::bigint[]) AND endereco NOT LIKE 'sha256:%'},
    $conf_ids,
  );

  # refs invalidadas (as do membro caem em cascata logo abaixo)
  $self->_exec(
    q{UPDATE clean.canal_confirmacao_refs
         SET invalidada_em = COALESCE(invalidada_em, NOW()),
             telegram_chat_pendente = NULL
       WHERE id = ANY(?::bigint[])
         AND (invalidada_em IS NULL OR telegram_chat_pendente IS NOT NULL)},
    \@ref_ids,
  );

  # membros removidos de todas as listas da escola
  my $n_membros = $self->_exec(
    q{DELETE FROM clean.canal_lista_membros WHERE id = ANY(?::bigint[])},
    \@membro_ids,
  );

  # inscrições do titular
  my $n_insc = $self->_exec(
    q{UPDATE clean.canal_inscricoes
         SET nome = ?, telefone = NULL, telefone_norm = NULL, email = NULL,
             email_norm = NULL, ip_anon = NULL, user_agent = NULL,
             anonimizado_em = NOW()
       WHERE id = ANY(?::bigint[]) AND anonimizado_em IS NULL},
    $REMOVIDO, \@insc_ids,
  );

  # telefone/e-mail do titular em inscrições de OUTROS contatos da escola
  # (conflito: a submissão de outra pessoa citou o endereço do titular)
  my @tel = sort keys %tel;
  my @mail = sort keys %mail;
  $self->_exec(
    q{UPDATE clean.canal_inscricoes i SET telefone = NULL, telefone_norm = NULL
        FROM clean.canal_listas l
       WHERE l.id = i.lista_id AND l.cod_inep = ? AND i.telefone_norm = ANY(?::text[])},
    $cod_inep, \@tel,
  ) if @tel;
  $self->_exec(
    q{UPDATE clean.canal_inscricoes i SET email = NULL, email_norm = NULL
        FROM clean.canal_listas l
       WHERE l.id = i.lista_id AND l.cod_inep = ? AND i.email_norm = ANY(?::text[])},
    $cod_inep, \@mail,
  ) if @mail;

  # o contato da escola
  my $n_contatos = $cid ? $self->_exec(
    q{UPDATE clean.contatos
         SET nome = ?, telefone = NULL, email = NULL, updated_at = NOW()
       WHERE id = ? AND (nome <> ? OR telefone IS NOT NULL OR email IS NOT NULL)},
    $REMOVIDO, $cid, $REMOVIDO,
  ) : 0;

  return {
    ok         => 1,
    contatos   => $n_contatos + 0,
    inscricoes => $n_insc + 0,
    membros    => $n_membros + 0,
  };
}

# Registro SEM PII em canal_exclusoes. Devolve o id.
sub _registrar_exclusao ($self, %p) {
  my $motivo = $p{motivo};
  $motivo = undef if ref $motivo;
  if (defined $motivo) {
    $motivo =~ s/^\s+|\s+$//g;
    $motivo = length $motivo ? substr($motivo, 0, 500) : undef;
  }
  my $gestor_id = $p{gestor_id};
  $gestor_id = undef unless defined $gestor_id && $gestor_id =~ /^\d+\z/;
  my $r = $self->_row(
    q{INSERT INTO clean.canal_exclusoes
        (cod_inep, origem, regra, gestor_id, motivo, contatos, inscricoes, membros)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      RETURNING id},
    $p{cod_inep} + 0, $p{origem}, $p{regra}, $gestor_id, $motivo,
    ($p{contatos} // 0) + 0, ($p{inscricoes} // 0) + 0, ($p{membros} // 0) + 0,
  );
  return $r->{id} + 0;
}

# ---------------------------------------------------------------------------
# retenção (RF-207)
# ---------------------------------------------------------------------------

our @REGRAS_RETENCAO = qw(metadados pendentes lista_inativa);

# Executa as três regras (cada uma na sua transação). %cfg: metadados_dias,
# pendentes_dias, listas_inativas_meses (default: retencao_config). Devolve
# { metadados => {contatos, inscricoes, membros, escolas}, pendentes => {...},
#   lista_inativa => {...} }. Uma regra que falha não impede as outras
# (`erro` na regra).
sub retencao_executar ($self, %cfg) {
  my $def = $self->retencao_config;
  $cfg{$_} //= $def->{$_} for qw(metadados_dias pendentes_dias listas_inativas_meses);

  my %out;
  for my $regra (@REGRAS_RETENCAO) {
    my $ok = eval {
      $self->schema->storage->txn_do(sub {
        my $por_escola = $self->can("_retencao_$regra")->($self, %cfg);
        $out{$regra} = $self->_retencao_registrar($regra, $por_escola);
      });
      1;
    };
    $out{$regra} = { erro => ($@ || 'falha'), contatos => 0, inscricoes => 0, membros => 0 }
      unless $ok;
  }
  return \%out;
}

# Grava a linha de resumo (cod_inep 0, mesmo com zero) + uma por escola com
# contagem. Devolve os totais.
sub _retencao_registrar ($self, $regra, $por_escola) {
  my %tot = (contatos => 0, inscricoes => 0, membros => 0);
  for my $inep (sort { $a <=> $b } keys %$por_escola) {
    my $c = $por_escola->{$inep};
    next unless $c->{contatos} || $c->{inscricoes} || $c->{membros};
    $tot{$_} += $c->{$_} // 0 for keys %tot;
    $self->_registrar_exclusao(cod_inep => $inep, origem => 'retencao',
                               regra => $regra, %$c);
  }
  $self->_registrar_exclusao(cod_inep => 0, origem => 'retencao', regra => $regra, %tot);
  return { %tot, escolas => scalar grep {
    my $c = $por_escola->{$_}; $c->{contatos} || $c->{inscricoes} || $c->{membros}
  } keys %$por_escola };
}

# metadados: ip_anon/user_agent NULL nas inscrições antigas.
sub _retencao_metadados ($self, %cfg) {
  my $rows = $self->_rows(
    q{UPDATE clean.canal_inscricoes i
         SET ip_anon = NULL, user_agent = NULL
        FROM clean.canal_listas l
       WHERE l.id = i.lista_id
         AND i.created_at < NOW() - make_interval(days => ?)
         AND (i.ip_anon IS NOT NULL OR i.user_agent IS NOT NULL)
      RETURNING l.cod_inep},
    $cfg{metadados_dias} + 0,
  );
  my %por;
  $por{ $_->{cod_inep} }{inscricoes}++ for @$rows;
  return \%por;
}

# pendentes: inscritos nunca confirmados de listas que exigem confirmação.
sub _retencao_pendentes ($self, %cfg) {
  my $dias = $cfg{pendentes_dias} + 0;
  my $alvos = $self->_rows(
    sprintf(q{SELECT DISTINCT l.cod_inep, m.contato_id
      FROM   clean.canal_lista_membros m
      JOIN   clean.canal_listas l ON l.id = m.lista_id
      WHERE  l.exige_confirmacao
        AND  m.confirmado_em IS NULL AND m.email_confirmado_em IS NULL
        AND  m.created_at < NOW() - make_interval(days => ?)
        AND  EXISTS (SELECT 1 FROM clean.canal_inscricoes i
                      WHERE i.lista_id = m.lista_id AND i.contato_id = m.contato_id)
        -- inscrição recente (em qualquer lista) reinicia o prazo
        AND  NOT EXISTS (SELECT 1 FROM clean.canal_inscricoes i
                          WHERE i.contato_id = m.contato_id
                            AND i.created_at >= NOW() - make_interval(days => ?))
        -- nenhum contato confirmado em nenhuma lista; nem membro de lista
        -- ativa sem exigência (lá o dado é legítimo)
        AND  NOT EXISTS (SELECT 1
                           FROM clean.canal_lista_membros m2
                           JOIN clean.canal_listas l2 ON l2.id = m2.lista_id
                          WHERE m2.contato_id = m.contato_id
                            AND (m2.confirmado_em IS NOT NULL
                                 OR m2.email_confirmado_em IS NOT NULL
                                 OR (l2.ativo AND NOT l2.exige_confirmacao)))
        AND  %s}, sprintf($SQL_NASCIDO_NA_INSCRICAO, 'm.contato_id')),
    $dias, $dias,
  );
  return $self->_retencao_anonimizar($alvos, 'pendentes');
}

# lista_inativa: membros de listas desativadas há mais que o prazo, exceto
# quem está em outra lista ativa.
sub _retencao_lista_inativa ($self, %cfg) {
  my $alvos = $self->_rows(
    sprintf(q{SELECT DISTINCT l.cod_inep, m.contato_id
      FROM   clean.canal_lista_membros m
      JOIN   clean.canal_listas l ON l.id = m.lista_id
      WHERE  NOT l.ativo
        AND  l.desativada_em IS NOT NULL
        AND  l.desativada_em < NOW() - make_interval(months => ?)
        AND  NOT EXISTS (SELECT 1
                           FROM clean.canal_lista_membros m2
                           JOIN clean.canal_listas l2 ON l2.id = m2.lista_id
                          WHERE m2.contato_id = m.contato_id AND l2.ativo)
        AND  %s}, sprintf($SQL_NASCIDO_NA_INSCRICAO, 'm.contato_id')),
    $cfg{listas_inativas_meses} + 0,
  );
  return $self->_retencao_anonimizar($alvos, 'lista_inativa');
}

sub _retencao_anonimizar ($self, $alvos, $regra) {
  my %por;
  for my $a (@$alvos) {
    my $r = $self->_anonimizar($a->{cod_inep}, $a->{contato_id}) or next;
    $por{ $a->{cod_inep} }{$_} += $r->{$_} for qw(contatos inscricoes membros);
  }
  return \%por;
}

# Última execução (linhas de resumo, cod_inep 0) ou undef:
# { em, metadados (inscrições), pendentes (contatos), listas_inativas
#   (contatos) }.
sub retencao_ultima_execucao ($self) {
  my $rows = $self->_rows(
    sprintf(q{SELECT DISTINCT ON (regra) regra, contatos, inscricoes,
                     created_at AS ts, %s AS em
              FROM   clean.canal_exclusoes
              WHERE  origem = 'retencao' AND cod_inep = 0
              ORDER  BY regra, created_at DESC, id DESC}, sprintf($ISO, 'created_at')),
  );
  return unless @$rows;
  my %r = map { $_->{regra} => $_ } @$rows;
  my ($ultima) = sort { $b->{ts} cmp $a->{ts} } @$rows;
  return {
    em              => $ultima->{em},
    metadados       => ($r{metadados}     ? $r{metadados}{inscricoes} + 0   : 0),
    pendentes       => ($r{pendentes}     ? $r{pendentes}{contatos} + 0     : 0),
    listas_inativas => ($r{lista_inativa} ? $r{lista_inativa}{contatos} + 0 : 0),
  };
}

# Prazos públicos (página /privacidade): { metadados_dias, pendentes_dias,
# listas_inativas_meses, enabled (booleano JSON) }.
sub retencao_publica ($self) {
  my $c = $self->retencao_config;
  return {
    enabled               => $c->{enabled} ? true : false,
    metadados_dias        => $c->{metadados_dias} + 0,
    pendentes_dias        => $c->{pendentes_dias} + 0,
    listas_inativas_meses => $c->{listas_inativas_meses} + 0,
  };
}

# Executa SQL de escrita e devolve o nº de linhas afetadas.
sub _exec ($self, $sql, @binds) {
  my $n;
  $self->schema->storage->dbh_do(sub ($me, $dbh) {
    $n = $dbh->do($sql, undef, @binds);
  });
  return ($n // 0) + 0;
}

1;
