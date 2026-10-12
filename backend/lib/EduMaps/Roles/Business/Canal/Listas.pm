package EduMaps::Roles::Business::Canal::Listas;
use Mojo::Base -role, -signatures;
use utf8;
use Mojo::JSON qw(true false);
use Digest::SHA qw(sha256_hex);
use EduMaps::Channel::Email;

# ============================================================================
# LISTAS NOMEADAS COM QR PARA AUTOINSCRIÇÃO DE CONTATOS (issue #208)
# ============================================================================
#
# Fase 0 — MVP (canal telefone, sem validação). Regras de negócio:
#
#   - telefone SENSÍVEL e NÃO DESTRUTIVO: guarda o bruto + normalizado (só
#     dígitos), MARCA (`validado`, `duplicado_de`, `conflito`) e NUNCA apaga;
#   - dedupe na camada de modelo: procura o contato da escola pelo telefone
#     normalizado; se existe, reusa (membro via ON CONFLICT DO NOTHING) e a
#     submissão vira histórico com `duplicado_de`/`conflito`; se não, cria o
#     contato (validado=false) + membro + inscrição;
#   - token UUID v4 (gerado pela aplicação via gen_random_uuid, sem default no
#     banco): rotacionar revoga o ativo anterior; expiração e max_usos
#     respeitados (410/429); revogação imediata.
#
# O endpoint público é unificado por canal (a API resolve token → lista →
# campos); `canal` é um atributo de dados da lista ('telefone' no MVP).
#
# Consome a role de config `EduMaps::Roles::Business::Config::AppConfig` para
# ler `canais.inscricao.*` (enabled, public_base_url, rate_max,
# rate_window_seconds).
#
# Fase 2 (#214) — e-mail e LGPD:
#
#   - `coleta` por lista: telefone | email | ambos | qualquer (default
#     telefone — Fases 0/1 intactas). Define os campos exibidos/obrigatórios;
#   - e-mail validado pelo Channel::Email (sem SMTP), bruto + normalizado
#     (minúsculas) na inscrição; dedupe NÃO destrutivo também por e-mail
#     (índice uq_contatos_inep_email): telefone e e-mail apontando para
#     contatos diferentes → reusa o do telefone e marca `conflito`;
#   - consentimento versionado (Canal::Consentimento): grava a versão vigente
#     + o hash do texto; versão enviada diferente da vigente → 409;
#   - token pessoal de exclusão (128 bits; só o SHA-256 no banco) devolvido
#     como `exclusao_url`;
#   - estado da confirmação POR CONTATO (telefone: confirmado_em/via; e-mail:
#     email_confirmado_em/via) e estado geral pendente|parcial|confirmado.

requires qw(schema);

has _rate_buckets => sub { {} };   # rate limit em memória (por processo)

# Fase 2 (#214): a versão gravada é a VIGENTE de clean.consentimento_versoes
# (Canal::Consentimento). A constante fica só como FALLBACK, quando a tabela
# não tem versão vigente.
our $CONSENTIMENTO_VERSAO = '1.0';

# Contatos coletados por lista (#214, RF-201). CHECK do banco é a fonte de
# verdade; a ordem é a do contrato.
our @COLETAS = qw(telefone email ambos qualquer);

# campos exibidos / obrigatórios por `coleta` (contrato da onda 1).
my %CAMPOS = (
  telefone => [ [qw(nome telefone)],       [qw(nome telefone)] ],
  email    => [ [qw(nome email)],          [qw(nome email)] ],
  ambos    => [ [qw(nome telefone email)], [qw(nome telefone email)] ],
  qualquer => [ [qw(nome telefone email)], [qw(nome)] ],
);

sub coleta_valida ($self, $coleta) {
  return defined $coleta && !ref $coleta && grep({ $_ eq $coleta } @COLETAS) ? 1 : 0;
}

sub campos_coleta ($self, $coleta) {
  my $c = $CAMPOS{ $coleta // 'telefone' } // $CAMPOS{telefone};
  return { campos => [ @{ $c->[0] } ], obrigatorios => [ @{ $c->[1] } ] };
}

# ---------------------------------------------------------------------------
# estado da confirmação por contato (#214, RF-203)
# ---------------------------------------------------------------------------
#
# Um membro tem os contatos PRESENTES na sua última inscrição na lista (sem
# inscrição — membro manual/importado — vale o que o contato tem). Cada
# contato presente é confirmado (telefone: confirmado_em; e-mail:
# email_confirmado_em) ou não. Estado geral: confirmado (todos), parcial
# (parte), senão pendente (lista exige) / nao_exigida.

# Última inscrição do membro `m` (alias `c` = contato) — LATERAL.
my $SQL_ULTIMA_INSCRICAO = q{LEFT JOIN LATERAL (
        SELECT i.id, i.telefone_norm, i.email, i.email_norm, i.conflito, i.duplicado_de
        FROM   clean.canal_inscricoes i
        WHERE  i.lista_id = m.lista_id AND i.contato_id = m.contato_id
        ORDER  BY i.id DESC LIMIT 1
      ) i ON TRUE};
my $SQL_TEM_TEL = q{(CASE WHEN i.id IS NOT NULL THEN COALESCE(i.telefone_norm, '') <> ''
                      ELSE COALESCE(c.telefone, '') <> '' END)};
my $SQL_TEM_EMAIL = q{(CASE WHEN i.id IS NOT NULL THEN COALESCE(i.email_norm, '') <> ''
                        ELSE COALESCE(c.email, '') <> '' END)};
my $SQL_GERAL_CONFIRMADO = "((NOT $SQL_TEM_TEL OR m.confirmado_em IS NOT NULL)
   AND (NOT $SQL_TEM_EMAIL OR m.email_confirmado_em IS NOT NULL)
   AND ($SQL_TEM_TEL OR $SQL_TEM_EMAIL
        OR m.confirmado_em IS NOT NULL OR m.email_confirmado_em IS NOT NULL))";

# Contagem de membros com estado geral `confirmado` da lista `l`.
my $SQL_N_CONFIRMADOS = "(SELECT count(*)::int
         FROM   clean.canal_lista_membros m
         JOIN   clean.contatos c ON c.id = m.contato_id
         $SQL_ULTIMA_INSCRICAO
         WHERE  m.lista_id = l.id AND $SQL_GERAL_CONFIRMADO)";

# Estado por contato e geral. Parâmetros: exige, tem_telefone, tem_email,
# confirmado_em, confirmado_via, email_confirmado_em, email_confirmado_via.
# Devolve { estado => confirmado|parcial|pendente|nao_exigida,
#           telefone => {estado, via, confirmado_em} | undef,
#           email    => {estado, via, confirmado_em} | undef }.
sub estado_contatos ($self, %p) {
  my $base = $p{exige} ? 'pendente' : 'nao_exigida';
  my %out;
  my ($presentes, $confirmados) = (0, 0);
  for my $k (qw(telefone email)) {
    my ($em, $via) = $k eq 'telefone'
      ? @p{qw(confirmado_em confirmado_via)}
      : @p{qw(email_confirmado_em email_confirmado_via)};
    unless ($p{"tem_$k"}) { $out{$k} = undef; next; }
    $presentes++;
    $confirmados++ if defined $em;
    $out{$k} = {
      estado        => defined $em ? 'confirmado' : $base,
      via           => defined $em ? $via : undef,
      confirmado_em => $em,
    };
  }

  if (!$presentes) {
    $out{estado} = (defined $p{confirmado_em} || defined $p{email_confirmado_em})
      ? 'confirmado' : $base;
  }
  elsif ($confirmados == $presentes) { $out{estado} = 'confirmado'; }
  elsif ($confirmados)               { $out{estado} = 'parcial'; }
  else                               { $out{estado} = $base; }
  return \%out;
}

# Só {estado, via} dos contatos presentes (formato `contatos` do contrato).
sub contatos_publicos ($self, $ec) {
  my %c;
  for my $k (qw(telefone email)) {
    next unless $ec->{$k};
    $c{$k} = { estado => $ec->{$k}{estado}, via => $ec->{$k}{via} };
  }
  return \%c;
}

# ---------------------------------------------------------------------------
# telefone: normalização (bruto + só dígitos)
# ---------------------------------------------------------------------------

# Número mínimo de dígitos para uma submissão ser útil (SEM validação de
# formato — decisão de produto do MVP).
sub telefone_min_digits { return 8; }

# Normaliza o telefone para a chave de comparação: somente dígitos.
sub normalize_phone ($self, $telefone) {
  return '' unless defined $telefone;
  return ($telefone =~ s/\D//gr);
}

# Nome normalizado para comparação de conflito (trim + colapsa espaços).
sub _normaliza_nome ($self, $nome) {
  $nome = '' unless defined $nome;
  $nome =~ s/^\s+|\s+$//g;
  $nome =~ s/\s+/ /g;
  return $nome;
}

# ---------------------------------------------------------------------------
# gestão: listas (A1)
# ---------------------------------------------------------------------------

sub listar_listas ($self, $cod_inep) {
  my $rows = $self->_rows(
    qq{SELECT l.*,
             (SELECT count(*)::int FROM clean.canal_lista_membros m
               WHERE m.lista_id = l.id) AS n_membros,
             $SQL_N_CONFIRMADOS AS membros_confirmados,
             (SELECT count(*)::int FROM clean.canal_qrcodes q
               WHERE q.lista_id = l.id AND q.status = 'ativo') AS n_qrcodes_ativos
      FROM   clean.canal_listas l
      WHERE  l.cod_inep = ? AND l.ativo
      ORDER  BY l.nome},
    $cod_inep + 0,
  );

  my @out;
  for my $r (@$rows) {
    my $qr = $self->_row(
      q{SELECT id, token::text AS token, status, expira_em, max_usos, usos,
               created_at, revogado_em
        FROM   clean.canal_qrcodes
        WHERE  lista_id = ?
        ORDER  BY id DESC LIMIT 1},
      $r->{id} + 0,
    );
    push @out, {
      id                => $r->{id} + 0,
      cod_inep          => $r->{cod_inep} + 0,
      gestor_id         => $r->{gestor_id} + 0,
      nome              => $r->{nome},
      canal             => $r->{canal},
      coleta            => $r->{coleta},
      descricao         => $r->{descricao},
      ativo             => $r->{ativo} ? 1 : 0,
      n_membros         => $r->{n_membros} + 0,
      n_qrcodes_ativos  => $r->{n_qrcodes_ativos} + 0,
      $self->_campos_confirmacao_lista($r),
      qrcode            => $qr ? $self->_qr_publico($qr) : undef,
      created_at        => $r->{created_at},
      updated_at        => $r->{updated_at},
    };
  }
  return \@out;
}

# Cria uma lista nomeada (nome único por escola). Se já existe uma lista
# DESATIVADA com o mesmo nome, reativa-a (mesma linha — preserva o histórico).
# Devolve o detalhe ou { error => 'Já existe uma lista com este nome nesta escola.' }.
sub criar_lista ($self, %p) {
  my ($cod_inep, $gestor_id) = @p{qw/cod_inep gestor_id/};

  my $nome = $p{nome} // '';
  $nome =~ s/^\s+|\s+$//g;
  return { error => 'nome é obrigatório (1..120 caracteres).' }
    unless length $nome >= 1 && length $nome <= 120;

  my $canal = $p{canal} // 'telefone';
  return { error => 'canal inválido (MVP: apenas telefone).' }
    unless $canal eq 'telefone';

  my $descricao = $p{descricao};
  $descricao = undef if defined $descricao && !length $descricao;

  # contatos coletados (#214): default telefone (Fases 0/1 intactas).
  my $coleta = $p{coleta} // 'telefone';
  return { error => 'coleta inválida (telefone, email, ambos ou qualquer).', invalido => 1 }
    unless $self->coleta_valida($coleta);

  # exigência de confirmação de posse (#212): default false (Fase 0 intacta).
  my $exige = 0;
  if (defined $p{exige_confirmacao}) {
    $exige = $self->parse_bool($p{exige_confirmacao});
    return { error => 'exige_confirmacao inválido (true/false).', invalido => 1 }
      unless defined $exige;
  }

  my $row = $self->_row(
    'INSERT INTO clean.canal_listas (cod_inep, gestor_id, nome, canal, descricao,
                                     exige_confirmacao, coleta)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (cod_inep, nome) DO UPDATE
       SET ativo = true, gestor_id = EXCLUDED.gestor_id,
           descricao = EXCLUDED.descricao,
           exige_confirmacao = EXCLUDED.exige_confirmacao,
           coleta = EXCLUDED.coleta, desativada_em = NULL, updated_at = NOW()
       WHERE clean.canal_listas.ativo = false
     RETURNING id',
    $cod_inep + 0, $gestor_id + 0, $nome, $canal, $descricao,
    $exige ? 1 : 0, $coleta,
  );
  return { error => 'Já existe uma lista com este nome nesta escola.' } unless $row;

  return $self->detalhe_lista($cod_inep + 0, $row->{id} + 0);
}

# Detalhe de uma lista + contagens (membros, inscrições, QRs ativos) + último QR.
sub detalhe_lista ($self, $cod_inep, $lista_id) {
  my $r = $self->_row(
    qq{SELECT l.*, g.nome AS gestor_nome,
             (SELECT count(*)::int FROM clean.canal_lista_membros m
               WHERE m.lista_id = l.id) AS n_membros,
             $SQL_N_CONFIRMADOS AS membros_confirmados,
             (SELECT count(*)::int FROM clean.canal_inscricoes i
               WHERE i.lista_id = l.id) AS n_inscricoes,
             (SELECT count(*)::int FROM clean.canal_qrcodes q
               WHERE q.lista_id = l.id AND q.status = 'ativo') AS n_qrcodes_ativos
      FROM   clean.canal_listas l
      LEFT JOIN clean.gestores g ON g.id = l.gestor_id
      WHERE  l.id = ? AND l.cod_inep = ?},
    $lista_id + 0, $cod_inep + 0,
  ) or return;

  my $qr = $self->_row(
    q{SELECT id, token::text AS token, status, expira_em, max_usos, usos,
             created_at, revogado_em
      FROM   clean.canal_qrcodes
      WHERE  lista_id = ?
      ORDER  BY id DESC LIMIT 1},
    $lista_id + 0,
  );

  return {
    id               => $r->{id} + 0,
    cod_inep         => $r->{cod_inep} + 0,
    gestor_id        => $r->{gestor_id} + 0,
    nome             => $r->{nome},
    canal            => $r->{canal},
    coleta           => $r->{coleta},
    descricao        => $r->{descricao},
    ativo            => $r->{ativo} ? 1 : 0,
    gestor_nome      => $r->{gestor_nome},
    n_membros        => $r->{n_membros} + 0,
    n_inscricoes     => $r->{n_inscricoes} + 0,
    n_qrcodes_ativos => $r->{n_qrcodes_ativos} + 0,
    $self->_campos_confirmacao_lista($r),
    qrcode           => $qr ? $self->_qr_publico($qr) : undef,
    created_at       => $r->{created_at},
    updated_at       => $r->{updated_at},
  };
}

# Edita uma lista (PATCH, #212; `coleta` #214): `nome`, `descricao`,
# `exige_confirmacao`, `coleta` —
# só os campos presentes em %campos. Mudar `exige_confirmacao` NÃO altera os
# membros já existentes (o estado é derivado na leitura). Devolve o detalhe;
# undef se a lista não é da escola; { error, status => 400|409 } nos erros.
sub atualizar_lista ($self, $cod_inep, $lista_id, %campos) {
  my $lista = $self->_lista_da_escola($cod_inep, $lista_id) or return;

  my (@set, @binds);
  if (exists $campos{nome}) {
    my $nome = $campos{nome} // '';
    $nome = '' if ref $nome;
    $nome =~ s/^\s+|\s+$//g;
    return { error => 'nome é obrigatório (1..120 caracteres).', status => 400 }
      unless length $nome >= 1 && length $nome <= 120;
    if ($nome ne $lista->{nome}) {
      my $dup = $self->_row(
        'SELECT 1 AS x FROM clean.canal_listas WHERE cod_inep = ? AND nome = ? AND id <> ?',
        $cod_inep + 0, $nome, $lista_id + 0,
      );
      return { error => 'Já existe uma lista com este nome nesta escola.', status => 409 }
        if $dup;
    }
    push @set, 'nome = ?';
    push @binds, $nome;
  }
  if (exists $campos{descricao}) {
    my $descricao = $campos{descricao};
    return { error => 'descricao inválida.', status => 400 } if ref $descricao;
    $descricao = undef if defined $descricao && !length $descricao;
    push @set, 'descricao = ?';
    push @binds, $descricao;
  }
  if (exists $campos{exige_confirmacao}) {
    my $exige = $self->parse_bool($campos{exige_confirmacao});
    return { error => 'exige_confirmacao inválido (true/false).', status => 400 }
      unless defined $exige;
    push @set, 'exige_confirmacao = ?';
    push @binds, $exige ? 1 : 0;
  }
  if (exists $campos{coleta}) {
    return { error => 'coleta inválida (telefone, email, ambos ou qualquer).', status => 400 }
      unless $self->coleta_valida($campos{coleta});
    push @set, 'coleta = ?';
    push @binds, $campos{coleta};
  }
  return { error => 'Nada a alterar (nome, descricao, exige_confirmacao ou coleta).', status => 400 }
    unless @set;

  my $ok = eval {
    $self->_rows(
      'UPDATE clean.canal_listas SET ' . join(', ', @set, 'updated_at = NOW()')
        . ' WHERE id = ? AND cod_inep = ?',
      @binds, $lista_id + 0, $cod_inep + 0,
    );
    1;
  };
  unless ($ok) {
    # corrida com outro gestor criando o mesmo nome (UNIQUE cod_inep, nome)
    return { error => 'Já existe uma lista com este nome nesta escola.', status => 409 }
      if ($@ // '') =~ /canal_listas_cod_inep_nome_key/;
    die $@;
  }

  return $self->detalhe_lista($cod_inep + 0, $lista_id + 0);
}

# Booleano tolerante para entradas da API: JSON true/false, 1/0, "true"/"false",
# "1"/"0". Devolve 1/0, ou undef se o valor não é um booleano reconhecível.
sub parse_bool ($self, $v) {
  return undef unless defined $v;
  if (ref $v) {
    return undef unless ref($v) =~ /Boolean/;
    return $v ? 1 : 0;
  }
  return 1 if $v =~ /^(?:1|true)\z/i;
  return 0 if $v =~ /^(?:0|false)\z/i;
  return undef;
}

# "Excluir/desativar" a lista (contrato de gestão). Implementado como
# DESATIVAÇÃO (ativo=false): preserva o histórico de inscrições e QRs (princípio
# "sem descarte" da spec). O DELETE CASCADE do schema continua valendo como
# fallback do banco para remoção física. `desativada_em` (#214) marca a
# desativação (base da retenção); idempotente — desativar de novo não a move.
sub excluir_lista ($self, $cod_inep, $lista_id) {
  my $row = $self->_row(
    'UPDATE clean.canal_listas
        SET ativo = false, updated_at = NOW(),
            desativada_em = CASE WHEN ativo THEN NOW() ELSE desativada_em END
      WHERE id = ? AND cod_inep = ?
      RETURNING id',
    $lista_id + 0, $cod_inep + 0,
  ) or return;
  return { id => $row->{id} + 0, ativo => 0 };
}

# ---------------------------------------------------------------------------
# gestão: QR (gerar/rotacionar/revogar)
# ---------------------------------------------------------------------------

# Gera (ou rotaciona) o QR da lista: revoga o ativo anterior e cria um novo
# token. Devolve o QR criado ou { error => 'not_found'|'lista_inativa' } ou
# { error => 'invalido', erro => <mensagem> } (#214, RF-209: `expira_em` ISO
# 8601 no futuro; `max_usos` inteiro > 0; ausentes/vazios = sem limite).
sub gerar_qrcode ($self, %p) {
  my ($cod_inep, $lista_id, $gestor_id) = @p{qw(cod_inep lista_id gestor_id)};

  my $lista = $self->_lista_da_escola($cod_inep, $lista_id);
  return { error => 'not_found' } unless $lista;
  return { error => 'lista_inativa' } unless $lista->{ativo};

  my $expira_em = $p{expira_em};
  $expira_em = undef if defined $expira_em && !ref $expira_em && $expira_em !~ /\S/;
  if (defined $expira_em) {
    my $erro = $self->_valida_expira_em($expira_em);
    return { error => 'invalido', erro => $erro } if $erro;
  }

  my $max_usos = $p{max_usos};
  $max_usos = undef if defined $max_usos && !ref $max_usos && $max_usos !~ /\S/;
  if (defined $max_usos) {
    $max_usos =~ s/^\s+|\s+$//g unless ref $max_usos;
    return { error => 'invalido', erro => 'max_usos deve ser um inteiro maior que zero.' }
      unless !ref $max_usos && $max_usos =~ /^\d{1,9}\z/ && $max_usos + 0 > 0;
    $max_usos += 0;
  }

  my $token = $self->_novo_token;
  my ($qr_id, $qr);
  $self->schema->storage->txn_do(sub {
    # rotação: invalida o token ativo anterior (revogado_em = NOW)
    $self->_rows(
      q{UPDATE clean.canal_qrcodes
           SET status = 'revogado', revogado_em = NOW()
         WHERE lista_id = ? AND status = 'ativo'},
      $lista_id + 0,
    );
    my $row = $self->_row(
      q{INSERT INTO clean.canal_qrcodes (lista_id, token, expira_em, max_usos, criado_por)
        VALUES (?, ?::uuid, ?::timestamptz, ?, ?)
        RETURNING id},
      $lista_id + 0, $token,
      (defined $expira_em ? $expira_em : undef),
      $max_usos,
      $gestor_id + 0,
    );
    $qr_id = $row->{id};
  });
  return { error => 'erro_interno' } unless defined $qr_id;

  $qr = $self->_row(
    q{SELECT id, token::text AS token, status, expira_em, max_usos, usos,
             created_at, revogado_em
      FROM   clean.canal_qrcodes
      WHERE  id = ?},
    $qr_id + 0,
  );
  return $self->_qr_publico($qr);
}

# `expira_em` do QR: data ISO 8601 (data, ou data e hora com fuso opcional —
# sem fuso vale o do servidor) estritamente no futuro. Devolve a mensagem de
# erro ou undef.
sub _valida_expira_em ($self, $v) {
  my $msg = 'expira_em deve ser uma data/hora ISO 8601 no futuro.';
  return $msg if ref $v;
  $v =~ s/^\s+|\s+$//g;
  return $msg unless $v =~ /^\d{4}-\d\d-\d\d
                            (?:[T\x20]\d\d:\d\d(?::\d\d(?:\.\d{1,6})?)?
                               (?:Z|[+-]\d\d(?::?\d\d)?)?)?\z/xi;
  my $r = eval {
    $self->_row(q{SELECT (?::timestamptz > NOW()) AS futura}, $v);
  };
  return $msg unless $r;           # data impossível (ex.: mês 13)
  return 'expira_em deve estar no futuro.' unless $r->{futura};
  return;
}

# Revoga o QR ativo da lista (imediato). Devolve o QR revogado ou
# { error => 'not_found'|'sem_qr_ativo' }.
sub revogar_qrcode ($self, $cod_inep, $lista_id) {
  my $lista = $self->_lista_da_escola($cod_inep, $lista_id);
  return { error => 'not_found' } unless $lista;

  my $row = $self->_row(
    q{UPDATE clean.canal_qrcodes
         SET status = 'revogado', revogado_em = NOW()
       WHERE lista_id = ? AND status = 'ativo'
       RETURNING id, token::text AS token, status, expira_em, max_usos,
                 usos, created_at, revogado_em},
    $lista_id + 0,
  );
  return $row
    ? $self->_qr_publico($row)
    : { error => 'sem_qr_ativo' };
}

# ---------------------------------------------------------------------------
# visão de membros (RF-006)
# ---------------------------------------------------------------------------

sub listar_inscricoes ($self, $cod_inep, $lista_id) {
  my $lista = $self->_lista_da_escola($cod_inep, $lista_id);
  return unless $lista;

  # e-mail exibido: o da agenda (contato) ou, se o contato não tem (ex.:
  # conflito — o e-mail já é de outro contato), o informado na inscrição.
  my $rows = $self->_rows(
    qq{SELECT m.id, m.lista_id, m.contato_id, m.origem, m.validado,
             m.confirmado_em, m.confirmado_via,
             m.email_confirmado_em, m.email_confirmado_via,
             m.created_at AS quando, c.nome, c.telefone,
             COALESCE(c.email, i.email) AS email,
             i.conflito, i.duplicado_de,
             $SQL_TEM_TEL AS tem_telefone, $SQL_TEM_EMAIL AS tem_email
      FROM   clean.canal_lista_membros m
      JOIN   clean.contatos c ON c.id = m.contato_id
      $SQL_ULTIMA_INSCRICAO
      WHERE  m.lista_id = ?
      ORDER  BY m.created_at DESC, c.nome},
    $lista_id + 0,
  );

  my $exige = $self->_row(
    'SELECT exige_confirmacao FROM clean.canal_listas WHERE id = ?', $lista_id + 0,
  )->{exige_confirmacao};

  my @out;
  for my $r (@$rows) {
    # estado da confirmação de posse (#212), por contato e geral (#214) —
    # derivado (não é coluna)
    my $ec = $self->estado_contatos(
      exige        => $exige,
      tem_telefone => $r->{tem_telefone},
      tem_email    => $r->{tem_email},
      map { $_ => $r->{$_} }
        qw(confirmado_em confirmado_via email_confirmado_em email_confirmado_via),
    );
    push @out, {
      id           => $r->{id} + 0,
      contato_id   => $r->{contato_id} + 0,
      nome         => $r->{nome},
      telefone     => $r->{telefone},
      email        => $r->{email},
      origem       => $r->{origem},
      validado     => $r->{validado} ? 1 : 0,
      conflito     => $r->{conflito} ? 1 : 0,
      duplicado_de => $r->{duplicado_de} ? $r->{duplicado_de} + 0 : undef,
      quando       => $r->{quando},
      estado              => $ec->{estado},
      telefone_estado     => $ec->{telefone} ? $ec->{telefone}{estado} : undef,
      email_estado        => $ec->{email}    ? $ec->{email}{estado}    : undef,
      confirmado_via      => $r->{confirmado_via},
      confirmado_em       => $r->{confirmado_em},
      email_confirmado_em => $r->{email_confirmado_em},
    };
  }
  return \@out;
}

# ---------------------------------------------------------------------------
# token público (A2): resolução + validação
# ---------------------------------------------------------------------------

# Resolve e valida o token. Devolve { ok => 1, ...row... } ou
# { ok => 0, reason => 'not_found'|'revogado'|'expirado'|'esgotado'|'lista_inativa' }.
# NÃO revela a existência do token em formato inválido (reason 'not_found').
sub validar_token ($self, $token) {
  return { ok => 0, reason => 'not_found' }
    unless defined $token && !ref $token && $token =~ /^[0-9a-fA-F-]{36}$/;

  my $r = $self->_row(
    q{SELECT q.id AS qrcode_id, q.token::text AS token, q.status, q.expira_em,
             q.max_usos, q.usos,
             (q.expira_em IS NOT NULL AND q.expira_em <= NOW()) AS vencido,
             (q.max_usos IS NOT NULL AND q.usos >= q.max_usos) AS esgotado,
             l.id AS lista_id, l.nome AS lista_nome, l.canal, l.ativo AS lista_ativa,
             l.cod_inep, l.gestor_id, l.exige_confirmacao, l.coleta,
             e.escola AS escola_nome
      FROM   clean.canal_qrcodes q
      JOIN   clean.canal_listas l ON l.id = q.lista_id
      LEFT JOIN clean.escolas e ON e.codigo_inep = l.cod_inep
      WHERE  q.token = ?::uuid},
    lc $token,
  );
  return { ok => 0, reason => 'not_found' } unless $r;

  if ($r->{status} eq 'revogado')      { return { ok => 0, reason => 'revogado' }; }
  if ($r->{status} eq 'expirado' || $r->{vencido}) {
    $self->_rows(
      q{UPDATE clean.canal_qrcodes SET status = 'expirado'
        WHERE id = ? AND status = 'ativo' AND expira_em <= NOW()},
      $r->{qrcode_id} + 0,
    ) if $r->{status} eq 'ativo';
    return { ok => 0, reason => 'expirado' };
  }
  if ($r->{esgotado}) { return { ok => 0, reason => 'esgotado' }; }
  if (!$r->{lista_ativa}) { return { ok => 0, reason => 'lista_inativa' }; }

  delete $r->{vencido};
  delete $r->{esgotado};
  delete $r->{lista_ativa};
  $r->{ok} = 1;
  $r->{qrcode_id}   = $r->{qrcode_id} + 0;
  $r->{lista_id}    = $r->{lista_id} + 0;
  $r->{cod_inep}    = $r->{cod_inep} + 0;
  $r->{gestor_id}   = $r->{gestor_id} + 0;
  $r->{exige_confirmacao} = $r->{exige_confirmacao} ? 1 : 0;
  return $r;
}

# Resposta mínima do GET público (RF-003): só o necessário para renderizar o
# formulário. NUNCA lista contatos nem expõe PII de terceiros. #214: `campos`
# e `obrigatorios` conforme a `coleta` da lista + consentimento vigente.
sub dados_publicos_token ($self, $token) {
  my $v = $self->validar_token($token);
  return $v unless $v->{ok};   # { ok => 0, reason => ... }
  my $c   = $self->campos_coleta($v->{coleta});
  my $vig = $self->consentimento_vigente;
  return {
    ok           => 1,
    lista_nome   => $v->{lista_nome},
    escola_nome  => $v->{escola_nome},
    canal        => $v->{canal},
    campos       => $c->{campos},
    obrigatorios => $c->{obrigatorios},
    consentimento => { versao => $vig->{versao}, texto => $vig->{texto} },
    expira_em    => $v->{expira_em},
  };
}

# ---------------------------------------------------------------------------
# inscrição pública (RF-004/RF-005): dedupe NÃO DESTRUTIVO
# ---------------------------------------------------------------------------

# Registra uma submissão de autoinscrição. Nunca apaga e nunca sobrescreve:
#
#   1. valida os campos conforme a `coleta` da lista (#214): telefone
#      normalizado (só dígitos); e-mail validado pelo Channel::Email e
#      normalizado (minúsculas); `qualquer` exige pelo menos um contato;
#   2. consentimento: obrigatório; `consentimento_versao` presente e diferente
#      da vigente → reason 'consentimento_versao' (409, com o texto vigente);
#      ausente → grava a vigente (compatibilidade);
#   3. dedupe na escola (telefone, depois e-mail):
#      - telefone acha um contato: reusa-o; se o e-mail acha OUTRO contato,
#        marca `conflito` e NÃO grava o e-mail no contato (índice único);
#      - só o e-mail acha um contato: reusa-o;
#      - reuso: NÃO sobrescreve — preenche só o que falta no contato
#        (e-mail/telefone NULL); membro via ON CONFLICT DO NOTHING; a
#        submissão vira histórico com duplicado_de=contato_id e
#        conflito = (nome difere do armazenado) ou (contatos divergentes);
#      - nenhum: cria o contato (validado=false), o membro e a inscrição;
#   4. token pessoal de exclusão (128 bits; só o SHA-256 em exclusao_hash);
#   5. incrementa `usos` do QR.
#
# Parâmetros: token, nome, telefone, email, consentimento (bool),
# consentimento_versao, ip_anon, user_agent. Devolve { ok => 1, inscricao_id,
# contato_id, membro_id, duplicado, conflito, exclusao_url, confirmacao? } ou
# { ok => 0, reason => 'campos'|'consentimento'|'consentimento_versao'|
#   'rate_limited'|'<token>', erro?, consentimento? }.
sub registrar_inscricao ($self, %p) {
  my $token = $p{token};
  my $v = $self->validar_token($token);
  return $v unless $v->{ok};

  my $coleta = $v->{coleta} // 'telefone';
  my %obrig  = map { $_ => 1 } @{ $self->campos_coleta($coleta)->{obrigatorios} };
  my %exibe  = map { $_ => 1 } @{ $self->campos_coleta($coleta)->{campos} };

  my $nome = $p{nome} // '';
  $nome = '' if ref $nome;
  $nome =~ s/^\s+|\s+$//g;
  return { ok => 0, reason => 'campos', erro => 'nome é obrigatório (1..120).' }
    unless length $nome >= 1 && length $nome <= 120;

  # telefone (só se a lista coleta telefone)
  my ($telefone, $telefone_norm);
  if ($exibe{telefone}) {
    $telefone = $p{telefone} // '';
    $telefone = '' if ref $telefone;
    $telefone =~ s/^\s+|\s+$//g;
    return { ok => 0, reason => 'campos', erro => 'telefone é obrigatório.' }
      if $obrig{telefone} && !length $telefone;
    if (length $telefone) {
      $telefone_norm = $self->normalize_phone($telefone);
      return { ok => 0, reason => 'campos',
               erro => 'telefone precisa de pelo menos ' . $self->telefone_min_digits . ' dígitos.' }
        unless length $telefone_norm >= $self->telefone_min_digits;
    }
    else { $telefone = undef; }
  }

  # e-mail (só se a lista coleta e-mail)
  my ($email, $email_norm);
  if ($exibe{email}) {
    $email = $p{email} // '';
    $email = '' if ref $email;
    $email =~ s/^\s+|\s+$//g;
    return { ok => 0, reason => 'campos', erro => 'e-mail é obrigatório.' }
      if $obrig{email} && !length $email;
    if (length $email) {
      my $ev = EduMaps::Channel::Email->new(config => {}, schema => undef)
                 ->validate_address($email);
      return { ok => 0, reason => 'campos', erro => 'e-mail inválido.' } unless $ev->{ok};
      $email_norm = $ev->{normalized};
    }
    else { $email = undef; }
  }

  return { ok => 0, reason => 'campos', erro => 'Informe pelo menos um contato (telefone ou e-mail).' }
    unless defined $telefone_norm || defined $email_norm;

  return { ok => 0, reason => 'consentimento' } unless $p{consentimento};

  # consentimento versionado (#214, RF-208)
  my $vig = $self->consentimento_vigente;
  my $versao_enviada = $p{consentimento_versao};
  $versao_enviada = undef if defined $versao_enviada && !ref $versao_enviada
                          && $versao_enviada !~ /\S/;
  if (defined $versao_enviada
      && (ref $versao_enviada || $versao_enviada ne $vig->{versao})) {
    return { ok => 0, reason => 'consentimento_versao',
             consentimento => { versao => $vig->{versao}, texto => $vig->{texto} } };
  }

  my $exclusao_token = $self->_row(
    q{SELECT encode(gen_random_bytes(16), 'hex') AS t}
  )->{t};

  my $resultado;
  my $ok = eval {
    $self->schema->storage->txn_do(sub {
      my ($contato_id, $duplicado_de, $conflito, $membro_id);

      # dedupe na camada de modelo — mesmo telefone normalizado na escola...
      my $por_tel = defined $telefone_norm ? $self->_row(
        q{SELECT id, nome, email, telefone
          FROM   clean.contatos
          WHERE  cod_inep = ? AND telefone IS NOT NULL
            AND regexp_replace(telefone, '\D', '', 'g') = ?
          ORDER  BY id LIMIT 1},
        $v->{cod_inep} + 0, $telefone_norm,
      ) : undef;
      # ... e mesmo e-mail (uq_contatos_inep_email, lower(email)).
      my $por_email = defined $email_norm ? $self->_row(
        q{SELECT id, nome, email, telefone
          FROM   clean.contatos
          WHERE  cod_inep = ? AND email IS NOT NULL AND lower(email) = ?
          ORDER  BY id LIMIT 1},
        $v->{cod_inep} + 0, $email_norm,
      ) : undef;

      my $existente = $por_tel // $por_email;
      if ($existente) {
        $contato_id   = $existente->{id} + 0;
        $duplicado_de = $contato_id;
        $conflito     = lc($self->_normaliza_nome($nome))
                      ne lc($self->_normaliza_nome($existente->{nome})) ? 1 : 0;
        # telefone e e-mail apontam para contatos diferentes: reusa o do
        # telefone e marca (nada é sobrescrito nem apagado).
        $conflito = 1 if $por_tel && $por_email && $por_tel->{id} != $por_email->{id};

        # preenche só o que falta no contato reusado (não destrutivo). O
        # e-mail só entra se não pertence a outro contato da escola.
        $self->_rows(
          q{UPDATE clean.contatos SET email = ?, updated_at = NOW()
             WHERE id = ? AND email IS NULL},
          $email, $contato_id,
        ) if defined $email && !$por_email;
        $self->_rows(
          q{UPDATE clean.contatos SET telefone = ?, updated_at = NOW()
             WHERE id = ? AND telefone IS NULL},
          $telefone, $contato_id,
        ) if defined $telefone && !$por_tel;

        # idempotência do pertencimento (UNIQUE lista_id, contato_id)
        my $m = $self->_row(
          q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem, validado)
            VALUES (?, ?, 'qrcode', false)
            ON CONFLICT (lista_id, contato_id) DO NOTHING
            RETURNING id},
          $v->{lista_id} + 0, $contato_id,
        ) || $self->_row(
          'SELECT id FROM clean.canal_lista_membros WHERE lista_id = ? AND contato_id = ?',
          $v->{lista_id} + 0, $contato_id,
        );
        $membro_id = $m->{id} + 0;
      }
      else {
        my $novo = $self->_row(
          q{INSERT INTO clean.contatos (cod_inep, gestor_id, nome, telefone, email)
            VALUES (?, ?, ?, ?, ?)
            RETURNING id},
          $v->{cod_inep} + 0, $v->{gestor_id} + 0, $nome, $telefone, $email,
        );
        $contato_id = $novo->{id} + 0;
        my $m = $self->_row(
          q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem, validado)
            VALUES (?, ?, 'qrcode', false)
            RETURNING id},
          $v->{lista_id} + 0, $contato_id,
        );
        $membro_id = $m->{id} + 0;
      }

      my $insc = $self->_row(
        q{INSERT INTO clean.canal_inscricoes
            (qrcode_id, lista_id, contato_id, nome, telefone, telefone_norm,
             email, email_norm,
             validado, duplicado_de, conflito, ip_anon, user_agent,
             consentimento_em, consentimento_versao, consentimento_hash,
             exclusao_hash)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, false, ?, ?, ?, ?, NOW(), ?, ?, ?)
          RETURNING id},
        $v->{qrcode_id} + 0, $v->{lista_id} + 0, $contato_id,
        $nome, $telefone, $telefone_norm,
        $email, $email_norm,
        $duplicado_de,
        $conflito ? 1 : 0,
        $p{ip_anon} // undef,
        $p{user_agent} // undef,
        $vig->{versao} // $CONSENTIMENTO_VERSAO,
        $vig->{texto_hash},
        sha256_hex($exclusao_token),
      );

      $self->_rows(
        'UPDATE clean.canal_qrcodes SET usos = usos + 1 WHERE id = ?',
        $v->{qrcode_id} + 0,
      );

      $resultado = {
        ok           => 1,
        inscricao_id => $insc->{id} + 0,
        contato_id   => $contato_id,
        membro_id    => $membro_id,
        duplicado    => $duplicado_de ? 1 : 0,
        conflito     => $conflito ? 1 : 0,
        exclusao_url => $self->url_exclusao(
          $self->inscricao_config->{public_base_url}, $exclusao_token),
      };

      # Lista que exige confirmação de posse (#212): na mesma transação, abre a
      # ref do membro pendente (invalida a anterior) ou informa que ele já está
      # confirmado. Método de Canal::Confirmacao (composta no model Canal).
      $resultado->{confirmacao} = $self->confirmacao_da_inscricao(
        $membro_id, $resultado->{inscricao_id},
      ) if $v->{exige_confirmacao};
    });
    1;
  };

  return $resultado if $ok && $resultado;
  return { ok => 0, reason => 'erro_interno', detalhe => ($@ // '') };
}

# ---------------------------------------------------------------------------
# rate limit (antiabuso — RNF-003)
# ---------------------------------------------------------------------------

# Rate limit básico por token + IP, janela curta, EM MEMÓRIA (por processo).
# Simples e sem dependência externa para o MVP; suficiente para um worker
# único. Valores em `canais.inscricao.rate_max` / `rate_window_seconds`.
# Degrada graciosamente: nunca 500 por abuso.
sub rate_limit_check ($self, %p) {
  my ($token, $ip) = @p{qw(token ip)};
  return { ok => 1 }
    unless defined $token && length $token
        && defined $ip && length $ip;

  my $cfg = $self->inscricao_config;
  # `max` opcional: orçamento próprio de outro endpoint público (ex.: GET da
  # confirmação, consultado em polling — #212).
  my $max = $p{max} // $cfg->{rate_max} // 10;
  my $win = $cfg->{rate_window_seconds} // 60;
  my $now = time;
  my $tick = int($now / $win);

  my $buckets = $self->_rate_buckets;
  if (!defined $buckets->{_tick} || $buckets->{_tick} != $tick) {
    # limpeza barata: derruba janelas passadas (a cada troca de tick)
    for my $k (keys %$buckets) {
      next if $k eq '_tick';
      delete $buckets->{$k} if $buckets->{$k}{tick} < $tick;
    }
    $buckets->{_tick} = $tick;
  }

  my $key  = "$token|$ip";
  my $b    = $buckets->{$key} //= { tick => $tick, n => 0 };
  if ($b->{tick} != $tick) { $b->{tick} = $tick; $b->{n} = 0; }
  return { ok => 0, reason => 'rate_limited' } if $b->{n} >= $max;

  $b->{n}++;
  return { ok => 1 };
}

# ---------------------------------------------------------------------------
# url pública do QR (RF-002)
# ---------------------------------------------------------------------------

sub url_inscricao ($self, $base_url, $token) {
  $base_url = '' unless defined $base_url;
  $base_url =~ s{/+$}{};
  return "$base_url/inscricao/$token";
}

# Link pessoal de exclusão do titular (#214, RF-204): a página pública
# /privacidade/exclusao/<token32hex> (rotas de exclusão: onda 2).
sub url_exclusao ($self, $base_url, $token) {
  $base_url = '' unless defined $base_url;
  $base_url =~ s{/+$}{};
  return "$base_url/privacidade/exclusao/$token";
}

# ---------------------------------------------------------------------------
# helpers privados
# ---------------------------------------------------------------------------

sub _qr_publico ($self, $q) {
  my $base = $self->inscricao_config->{public_base_url};
  return {
    id          => $q->{id} + 0,
    token       => $q->{token},
    url         => $self->url_inscricao($base, $q->{token}),
    status      => $q->{status},
    expira_em   => $q->{expira_em},
    max_usos    => $q->{max_usos},
    usos        => $q->{usos} + 0,
    created_at  => $q->{created_at},
    revogado_em => $q->{revogado_em},
  };
}

# Estado da confirmação de um membro (#212), derivado: `confirmado` se há
# confirmado_em; senão `pendente` se a lista exige; senão `nao_exigida`.
sub estado_membro ($self, $exige, $confirmado_em) {
  return 'confirmado' if defined $confirmado_em;
  return $exige ? 'pendente' : 'nao_exigida';
}

# Campos de confirmação no resumo/detalhe da lista. `membros_pendentes` só
# conta quando a lista exige (senão 0).
sub _campos_confirmacao_lista ($self, $r) {
  my $exige = $r->{exige_confirmacao} ? 1 : 0;
  my $conf  = ($r->{membros_confirmados} // 0) + 0;
  return (
    exige_confirmacao   => $exige ? true : false,   # booleano JSON (contrato #212)
    membros_confirmados => $conf,
    membros_pendentes   => $exige ? ($r->{n_membros} + 0) - $conf : 0,
  );
}

sub _lista_da_escola ($self, $cod_inep, $lista_id) {
  return $self->_row(
    q{SELECT id, cod_inep, gestor_id, nome, canal, ativo
      FROM   clean.canal_listas
      WHERE  id = ? AND cod_inep = ?},
    $lista_id + 0, $cod_inep + 0,
  );
}

# Token UUID v4 gerado pela aplicação (sem default no banco).
sub _novo_token ($self) {
  return $self->_row('SELECT gen_random_uuid()::text AS token')->{token};
}

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0];
}

1;