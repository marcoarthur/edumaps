package EduMaps::Roles::Business::Pesquisa::Gestores;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(hmac_sha256_hex);

# Gestores escolares: cadastro/upsert por e-mail + login (fase 2).
# LGPD: o CPF é armazenado, mas NUNCA é devolvido completo — apenas mascarado.
# Senha: nunca em claro — hash HMAC-SHA256(senha, salt) no formato "<salt_hex>:<hmac_hex>".
# Sessão: token bearer aleatório (uuid) em clean.sessoes, com expiração.

requires qw(schema);

sub upsert_gestor ($self, $params = {}) {
  # senha vem crua; o hash é calculado aqui (nunca vaza para o SQL).
  my $senha_hash = $params->{senha} ? $self->_hash_senha($params->{senha}) : undef;

  my $sql = <<~'SQL';
    INSERT INTO clean.gestores (cod_inep, nome, email, telefone, cargo, cpf, senha_hash)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (email) DO UPDATE SET
      cod_inep   = EXCLUDED.cod_inep,
      nome       = EXCLUDED.nome,
      telefone   = EXCLUDED.telefone,
      cargo      = EXCLUDED.cargo,
      cpf        = COALESCE(EXCLUDED.cpf, clean.gestores.cpf),
      senha_hash = COALESCE(EXCLUDED.senha_hash, clean.gestores.senha_hash),
      updated_at = NOW()
    RETURNING id, cod_inep, nome, email, telefone, cargo, cpf
  SQL

  my $row = $self->_row(
    $sql,
    $params->{cod_inep} + 0,
    $params->{nome},
    $params->{email},
    $params->{telefone} // undef,
    $params->{cargo}    // undef,
    $params->{cpf}      // undef,
    $senha_hash,
  ) or return;

  return {
    id         => $row->{id} + 0,
    cod_inep   => $row->{cod_inep} + 0,
    nome       => $row->{nome},
    email      => $row->{email},
    telefone   => $row->{telefone},
    cargo      => $row->{cargo},
    cpf_masc   => $self->_mask_cpf($row->{cpf}),
    created_at => $row->{created_at},
    updated_at => $row->{updated_at},
  };
}

sub gestor_for_id ($self, $id) {
  return $self->_row(
    'SELECT id, cod_inep, nome, email FROM clean.gestores WHERE id = ?',
    $id + 0,
  );
}

# ---------------------------------------------------------------
# regras do auto-cadastro governado (Plano A)
# ---------------------------------------------------------------

# A escola precisa existir (tabela curada ou censo mais recente).
sub escola_existe ($self, $cod_inep) {
  return $self->_row(
    'SELECT 1
     WHERE EXISTS (SELECT 1 FROM clean.escolas      WHERE codigo_inep = ?)
        OR EXISTS (SELECT 1 FROM clean.censo_escolas WHERE co_entidade = ?)
     LIMIT 1',
    $cod_inep + 0, $cod_inep + 0,
  ) ? 1 : 0;
}

sub gestor_email_existe ($self, $email) {
  return $self->_row(
    'SELECT 1 FROM clean.gestores WHERE lower(email) = lower(?) LIMIT 1',
    $email,
  ) ? 1 : 0;
}

# A escola já tem agenda (primeira reunião criada por um gestor)?
sub escola_tem_agenda ($self, $cod_inep) {
  return $self->_row(
    'SELECT 1 FROM clean.reunioes WHERE cod_inep = ? AND gestor_id IS NOT NULL LIMIT 1',
    $cod_inep + 0,
  ) ? 1 : 0;
}

# ---------------------------------------------------------------
# login / sessão
# ---------------------------------------------------------------

sub login_gestor ($self, $email, $senha) {
  my $g = $self->_row(
    'SELECT id, cod_inep, nome, email, senha_hash FROM clean.gestores WHERE email = ?',
    $email,
  );

  return undef unless $g && $g->{senha_hash} && $self->_verify_senha($senha, $g->{senha_hash});

  # limpa sessões expiradas do gestor numa passada barata
  $self->_rows(
    'DELETE FROM clean.sessoes WHERE gestor_id = ? AND expires_at < NOW()',
    $g->{id} + 0,
  );

  my $row = $self->_row(
    'INSERT INTO clean.sessoes (gestor_id, token, expires_at)
     VALUES (?, gen_random_uuid()::text, NOW() + interval \'30 days\')
     RETURNING token, expires_at',
    $g->{id} + 0,
  ) or return;

  return {
    token     => $row->{token},
    expira_em => $row->{expires_at},
    gestor    => {
      id       => $g->{id} + 0,
      cod_inep => $g->{cod_inep} + 0,
      nome     => $g->{nome},
      email    => $g->{email},
    },
  };
}

sub sessao_valida ($self, $token) {
  return unless defined $token && length($token) <= 64;
  return $self->_row(
    'SELECT g.id, g.cod_inep, g.nome, g.email
     FROM   clean.sessoes s
     JOIN   clean.gestores g ON g.id = s.gestor_id
     WHERE  s.token = ? AND s.expires_at > NOW()',
    $token,
  );
}

sub logout_gestor ($self, $token) {
  $self->_rows('DELETE FROM clean.sessoes WHERE token = ?', $token);
  return 1;
}

sub _hash_senha ($self, $senha) {
  my $salt = $self->_row('SELECT gen_random_uuid() AS u')->{u} // '';
  $salt =~ s/-//g;
  return $salt . ':' . hmac_sha256_hex($senha, $salt);
}

sub _verify_senha ($self, $senha, $stored) {
  return unless $stored =~ /^([0-9a-f]{32}):([0-9a-f]{64})$/;
  return hmac_sha256_hex($senha, $1) eq $2;
}

sub _mask_cpf ($self, $cpf) {
  return undef unless defined $cpf && $cpf =~ /^\d{11}$/;
  return '***.***.***-' . substr($cpf, -3);
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