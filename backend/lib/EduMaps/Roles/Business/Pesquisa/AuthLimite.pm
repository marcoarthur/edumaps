package EduMaps::Roles::Business::Pesquisa::AuthLimite;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(hmac_sha256_hex);

# Limite de tentativas de login e de cadastro do gestor (#335).
#
# Janela deslizante sobre clean.auth_falhas: uma linha por tentativa que
# conta. Bloqueado = há `max` linhas ou mais dentro da janela; o bloqueio
# acaba quando a mais antiga dessas `max` sai da janela (é o Retry-After).
# A contagem vive no banco para valer com vários workers e após reinícios.
#
# A chave é HMAC (segredo da aplicação) do valor normalizado — e-mail em
# minúsculas ou IP —, para a tabela não guardar dado pessoal legível.

requires qw(schema _row _rows);

# Linhas mais velhas que isto são apagadas a cada registro (maior janela em
# uso com folga; nenhuma janela configurada deve passar disso).
use constant RETENCAO_SEGUNDOS => 86_400;

sub auth_chave ($self, $secret, $valor) {
  return hmac_sha256_hex(lc($valor // ''), $secret // '');
}

# Segundos até liberar (0 = não bloqueado).
sub auth_retry_after ($self, $escopo, $chave, $max, $janela) {
  my $row = $self->_row(<<~'SQL', $janela, $escopo, $chave, $janela, $max);
    SELECT count(*) AS n,
           GREATEST(1, ceil(extract(epoch FROM
             min(criado_em) + make_interval(secs => ?) - now())))::int AS espera
      FROM (SELECT criado_em
              FROM clean.auth_falhas
             WHERE escopo = ? AND chave = ?
               AND criado_em > now() - make_interval(secs => ?)
             ORDER BY criado_em DESC
             LIMIT ?) ultimas
    SQL
  return 0 unless $row && $row->{n} >= $max;
  return $row->{espera} + 0;
}

sub auth_registrar ($self, $escopo, $chave) {
  $self->_rows('INSERT INTO clean.auth_falhas (escopo, chave) VALUES (?, ?)', $escopo, $chave);
  $self->_rows('DELETE FROM clean.auth_falhas WHERE criado_em < now() - make_interval(secs => ?)',
    RETENCAO_SEGUNDOS);
  return 1;
}

sub auth_limpar ($self, $escopo, $chave) {
  $self->_rows('DELETE FROM clean.auth_falhas WHERE escopo = ? AND chave = ?', $escopo, $chave);
  return 1;
}

1;
