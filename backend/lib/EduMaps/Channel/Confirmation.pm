package EduMaps::Channel::Confirmation;
use Mojo::Base -base, -signatures;
use utf8;

use Digest::SHA qw(sha256_hex);

# ============================================================================
# CONFIRMAÇÃO DE POSSE DE ENDEREÇO (CANAL)
# ============================================================================
#
# Fluxo: `start` gera um código de 6 dígitos, guarda apenas o HASH (código +
# salt) em clean.canal_confirmacoes e o canal envia o código ao destinatário;
# `verify` confere o código com limite de tentativas e dentro da validade.
# Um pedido pendente novo invalida os anteriores do mesmo canal+endereço.
#
# O código em claro nunca é persistido. O salt é aleatório por pedido.

has schema       => undef;
has log          => sub { Mojo::Log->new };
has ttl_seconds  => 600;
has max_attempts => 5;

# Inicia um pedido. Devolve { ok, id, codigo } (o código só existe em memória,
# para o canal enviar; nunca é gravado nem devolvido por API).
sub start ($self, %p) {
  my ($canal, $endereco) = @p{qw(canal endereco)};
  return { ok => 0, error => 'canal e endereço são obrigatórios' }
    unless defined $canal && length $canal
        && defined $endereco && length $endereco;

  # invalida pedidos pendentes anteriores do mesmo canal+endereço
  $self->_rows(
    q{UPDATE clean.canal_confirmacoes
         SET expira_em = NOW()
       WHERE canal = ? AND endereco = ?
         AND confirmado_em IS NULL AND expira_em > NOW()},
    $canal, $endereco,
  );

  my $codigo = sprintf('%06d', int(rand(1_000_000)));
  my $salt   = sha256_hex(join(':', time, $$, rand(), $endereco));
  my $hash   = sha256_hex(join(':', $codigo, $salt));

  my $row = $self->_row(
    q{INSERT INTO clean.canal_confirmacoes
        (canal, endereco, codigo_hash, salt, expira_em, contato_id, cod_inep)
      VALUES (?, ?, ?, ?, NOW() + (?::int * interval '1 second'), ?, ?)
      RETURNING id},
    $canal, $endereco, $hash, $salt, $self->ttl_seconds,
    (defined $p{contato_id} ? $p{contato_id} + 0 : undef),
    (defined $p{cod_inep}   ? $p{cod_inep} + 0   : undef),
  );

  return { ok => 1, id => $row->{id}, codigo => $codigo };
}

# Confere o código do pedido pendente mais recente.
# Devolve { ok => 1, confirmacao_id } ou { ok => 0, reason }.
sub verify ($self, %p) {
  my ($canal, $endereco, $codigo) = @p{qw(canal endereco codigo)};
  return { ok => 0, reason => 'canal e endereço são obrigatórios' }
    unless defined $canal && length $canal
        && defined $endereco && length $endereco;
  return { ok => 0, reason => 'código obrigatório' }
    unless defined $codigo && length $codigo;

  my $row = $self->_row(
    q{SELECT id, codigo_hash, salt, tentativas
        FROM clean.canal_confirmacoes
       WHERE canal = ? AND endereco = ?
         AND confirmado_em IS NULL AND expira_em > NOW()
       ORDER BY id DESC
       LIMIT 1},
    $canal, $endereco,
  );
  return { ok => 0, reason => 'sem pedido pendente' } unless $row->{id};

  if ($row->{tentativas} >= $self->max_attempts) {
    return { ok => 0, reason => 'tentativas excedidas' };
  }

  my $hash = sha256_hex(join(':', $codigo, $row->{salt}));
  if ($hash eq $row->{codigo_hash}) {
    $self->_rows(
      q{UPDATE clean.canal_confirmacoes
           SET confirmado_em = NOW(), tentativas = tentativas + 1
         WHERE id = ?},
      $row->{id},
    );
    return { ok => 1, confirmacao_id => $row->{id} };
  }

  $self->_rows(
    q{UPDATE clean.canal_confirmacoes SET tentativas = tentativas + 1 WHERE id = ?},
    $row->{id},
  );
  return { ok => 0, reason => 'código inválido' };
}

# --- helpers SQL (padrão das roles de negócio) -----------------------------

sub _rows ($self, $sql, @binds) {
  my $storage = $self->schema->storage;
  my $rows;
  $storage->dbh_do(sub ($me, $dbh) {
    $rows = $dbh->selectall_arrayref($sql, { Slice => {} }, @binds);
  });
  return $rows // [];
}

sub _row ($self, $sql, @binds) {
  return $self->_rows($sql, @binds)->[0] // {};
}

1;
