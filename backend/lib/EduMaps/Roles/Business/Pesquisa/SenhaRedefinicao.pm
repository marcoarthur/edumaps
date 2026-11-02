package EduMaps::Roles::Business::Pesquisa::SenhaRedefinicao;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(sha256_hex);
use Crypt::URandom qw(urandom);
use MIME::Base64 qw(encode_base64url);

# "Esqueci minha senha" do gestor (#336).
#
# Token: 32 bytes aleatórios em base64url (256 bits), enviado por e-mail. O
# banco guarda só o SHA-256 (clean.senha_redefinicoes.token_hash). Uso único,
# validade curta; um pedido novo invalida os anteriores. Usar o token grava a
# senha nova (Argon2id) e encerra todas as sessões do gestor.

requires qw(schema _row _rows _hash_senha);

use constant VALIDADE_MINUTOS => 30;

sub _token_hash ($self, $token) { sha256_hex($token // '') }

sub gestor_por_email ($self, $email) {
  return $self->_row(
    'SELECT id, nome, email FROM clean.gestores WHERE lower(email) = lower(?)',
    $email // '',
  );
}

# Cria o pedido e devolve o token em claro (só em memória: vai para o e-mail).
sub redefinicao_criar ($self, $gestor_id) {
  my $token = encode_base64url(urandom(32));
  $self->schema->storage->txn_do(sub {
    $self->_rows(
      'UPDATE clean.senha_redefinicoes SET usado_em = now()
        WHERE gestor_id = ? AND usado_em IS NULL',
      $gestor_id + 0,
    );
    $self->_rows(
      'INSERT INTO clean.senha_redefinicoes (gestor_id, token_hash, expira_em)
       VALUES (?, ?, now() + make_interval(mins => ?))',
      $gestor_id + 0, $self->_token_hash($token), VALIDADE_MINUTOS,
    );
  });
  return $token;
}

# Usa o token: grava a senha nova, marca o pedido como usado e encerra as
# sessões. Devolve { id, email } do gestor, ou undef se o token não vale
# (inexistente, vencido ou já usado — indistinguíveis para quem pede).
sub redefinicao_usar ($self, $token, $senha) {
  return unless defined $token && $token =~ /^[A-Za-z0-9_-]{43}$/;
  my $hash = $self->_token_hash($token);
  my $gestor;
  $self->schema->storage->txn_do(sub {
    my $r = $self->_row(
      'UPDATE clean.senha_redefinicoes SET usado_em = now()
        WHERE token_hash = ? AND usado_em IS NULL AND expira_em > now()
        RETURNING gestor_id',
      $hash,
    ) or return;
    $gestor = $self->_row(
      'UPDATE clean.gestores SET senha_hash = ?, updated_at = now()
        WHERE id = ? RETURNING id, email',
      $self->_hash_senha($senha), $r->{gestor_id} + 0,
    ) or return;
    $self->_rows('DELETE FROM clean.sessoes WHERE gestor_id = ?', $gestor->{id} + 0);
  });
  return $gestor;
}

1;
