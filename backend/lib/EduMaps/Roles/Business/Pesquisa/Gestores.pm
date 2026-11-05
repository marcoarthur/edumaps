package EduMaps::Roles::Business::Pesquisa::Gestores;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(hmac_sha256_hex sha256_hex);
use Crypt::Argon2 qw(argon2id_pass argon2_verify argon2_needs_rehash);
use Crypt::URandom qw(urandom);
use Encode ();

# Argon2id (#334). 64 MiB, t=3, p=1 (2ª opção da RFC 9106, com p=1): medido
# no backend.edumaps (4 núcleos) em ~128 ms por hash, dentro da meta de
# 100–300 ms; o mínimo da OWASP (19 MiB, t=2) custava só 22 ms lá. Subir um
# parâmetro faz os hashes antigos serem regravados no próximo login.
use constant {
  ARGON2_T_COST   => 3,
  ARGON2_M_COST   => '64M',
  ARGON2_PARALLEL => 1,
  ARGON2_TAG_LEN  => 32,
  ARGON2_SALT_LEN => 16,
};

# Gestores escolares: cadastro (só cria conta) + login (fase 2).
# LGPD: o CPF é armazenado, mas NUNCA é devolvido completo — apenas mascarado.
# Senha: nunca em claro — Argon2id no formato padrão "$argon2id$v=19$m=…".
#   Formato antigo (até 2026-11): "<salt_hex>:<hmac_sha256_hex>" — ainda aceito
#   no login e regravado em Argon2id na hora (re-hash transparente).
# Sessão: token bearer aleatório (32 bytes, hex) com expiração. O banco guarda
#   só o SHA-256 dele (clean.sessoes.token_hash); o token em claro vai uma
#   única vez ao cliente, no login.
# E-mail: gravado e comparado em minúsculas (índice único em lower(email)).

requires qw(schema);

# Cria a conta do gestor. Rota anônima: NUNCA altera uma conta existente.
# Conflito (e-mail, em qualquer caixa, ou CPF já cadastrados) devolve undef;
# o controller responde 409.
sub cadastrar_gestor ($self, $params = {}) {
  # senha vem crua; o hash é calculado aqui (nunca vaza para o SQL).
  my $senha_hash = $self->_hash_senha($params->{senha});

  my $sql = <<~'SQL';
    INSERT INTO clean.gestores (cod_inep, nome, email, telefone, cargo, cpf, senha_hash)
    VALUES (?, ?, lower(?), ?, ?, ?, ?)
    ON CONFLICT DO NOTHING
    RETURNING id, cod_inep, nome, email, telefone, cargo, cpf, created_at, updated_at
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
    'SELECT id, cod_inep, nome, email, senha_hash, access_role FROM clean.gestores WHERE lower(email) = lower(?)',
    $email,
  );

  # Sem conta (ou sem senha): verifica contra um hash fictício com os mesmos
  # parâmetros, para a resposta levar o mesmo tempo de uma senha errada e o
  # tempo não revelar quais e-mails têm conta (#335).
  unless ($g && $g->{senha_hash}) {
    $self->_verify_senha($senha, $self->_hash_ficticio);
    return undef;
  }
  return undef unless $self->_verify_senha($senha, $g->{senha_hash});

  # Senha conferida: hash antigo (HMAC) ou com parâmetros abaixo dos atuais é
  # regravado em Argon2id agora, sem pedir troca de senha.
  if ($self->_senha_precisa_rehash($g->{senha_hash})) {
    $self->_rows('UPDATE clean.gestores SET senha_hash = ? WHERE id = ?',
      $self->_hash_senha($senha), $g->{id} + 0);
  }

  # limpa sessões expiradas do gestor numa passada barata
  $self->_rows(
    'DELETE FROM clean.sessoes WHERE gestor_id = ? AND expires_at < NOW()',
    $g->{id} + 0,
  );

  my $token = unpack 'H*', urandom(32);
  my $row = $self->_row(
    'INSERT INTO clean.sessoes (gestor_id, token_hash, expires_at)
     VALUES (?, ?, NOW() + interval \'30 days\')
     RETURNING expires_at',
    $g->{id} + 0, _sessao_token_hash($token),
  ) or return;

  return {
    token     => $token,
    expira_em => $row->{expires_at},
    gestor    => {
      id          => $g->{id} + 0,
      cod_inep    => $g->{cod_inep} + 0,
      nome        => $g->{nome},
      email       => $g->{email},
      access_role => $g->{access_role} // 'gestor',
    },
  };
}

# ---------------------------------------------------------------
# admin de instalação via config (PROVISÓRIO)
# ---------------------------------------------------------------
# MECANISMO PROVISÓRIO (migrar p/ gestão própria de administradores):
# credenciais admin em texto plano no edu_maps.conf (bloco `admin`), apenas
# para bootstrap do operador no deploy. O controller de login confere o
# usuário/senha contra o config ANTES de chamar isto; batendo, o gestor admin
# é materializado em clean.gestores (INEP reservado 0 + access_role='admin') e
# a sessão segue o fluxo normal. Planejar substituição por CADASTRO de admin
# gerenciado.

sub login_admin_config ($self, $email, $senha) {
  return unless defined $email && defined $senha;

  my $row = $self->_row(
    'SELECT id FROM clean.gestores WHERE lower(email) = lower(?)',
    $email,
  );

  my $id;
  if ($row) {
    $id = $row->{id} + 0;
  } else {
    my $new = $self->_row(
      'INSERT INTO clean.gestores (cod_inep, nome, email, senha_hash, access_role)
       VALUES (0, ?, lower(?), ?, ?)
       ON CONFLICT DO NOTHING
       RETURNING id',
      'Administrador da Instalação',
      $email,
      $self->_hash_senha($senha),
      'admin',
    ) or return;
    $id = $new->{id} + 0;
  }

  # garante papel admin (idempotente em análises de repetidas logins)
  $self->_rows('UPDATE clean.gestores SET access_role = ? WHERE id = ?', 'admin', $id);

  return $self->login_gestor($email, $senha);
}

sub sessao_valida ($self, $token) {
  return unless defined $token && length($token) <= 64;
  return $self->_row(
    'SELECT g.id, g.cod_inep, g.nome, g.email, g.access_role
     FROM   clean.sessoes s
     JOIN   clean.gestores g ON g.id = s.gestor_id
     WHERE  s.token_hash = ? AND s.expires_at > NOW()',
    _sessao_token_hash($token),
  );
}

sub logout_gestor ($self, $token) {
  return 1 unless defined $token && length $token;
  $self->_rows('DELETE FROM clean.sessoes WHERE token_hash = ?', _sessao_token_hash($token));
  return 1;
}

# SHA-256 do token bearer, como guardado em clean.sessoes.token_hash. Hash
# simples basta: o token tem 256 bits aleatórios (não é senha, não há o que
# adivinhar). Mesma fórmula da migration sessoes_token_hash para os tokens
# antigos (uuid), que seguem válidos até expirar.
sub _sessao_token_hash ($token) { sha256_hex(Encode::encode('UTF-8', $token)) }

sub _hash_senha ($self, $senha) {
  return argon2id_pass($senha, urandom(ARGON2_SALT_LEN),
    ARGON2_T_COST, ARGON2_M_COST, ARGON2_PARALLEL, ARGON2_TAG_LEN);
}

# Calculado uma vez por processo (custa o mesmo que um hash real).
my $HASH_FICTICIO;
sub _hash_ficticio ($self) {
  return $HASH_FICTICIO //= $self->_hash_senha(unpack 'H*', urandom(16));
}

sub _verify_senha ($self, $senha, $stored) {
  return 0 unless defined $senha && defined $stored;
  return argon2_verify($stored, $senha) ? 1 : 0 if $stored =~ /^\$argon2/;

  # formato antigo — só verificação; nada novo é gravado assim
  return 0 unless $stored =~ /^([0-9a-f]{32}):([0-9a-f]{64})$/;
  return _iguais(hmac_sha256_hex($senha, $1), $2);
}

sub _senha_precisa_rehash ($self, $stored) {
  return 1 unless $stored =~ /^\$argon2id\$/;
  return argon2_needs_rehash($stored, 'argon2id',
    ARGON2_T_COST, ARGON2_M_COST, ARGON2_PARALLEL, ARGON2_TAG_LEN, ARGON2_SALT_LEN) ? 1 : 0;
}

# Comparação em tempo constante (o `eq` para no primeiro byte diferente).
sub _iguais ($x, $y) {
  return 0 unless length $x == length $y;
  my $diff = 0;
  $diff |= ord(substr $x, $_, 1) ^ ord(substr $y, $_, 1) for 0 .. length($x) - 1;
  return $diff == 0 ? 1 : 0;
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