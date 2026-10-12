package EduMaps::Roles::Business::Canal::Optout;
use Mojo::Base -role, -signatures;
use utf8;
use Digest::SHA qw(sha256_hex);

# ============================================================================
# OPT-OUT POR LISTA (issue #216 — Fase 3, onda 2, RF-303)
# ============================================================================
#
# Cada e-mail de envio traz o link `<base>/privacidade/sair/<token>` (e o
# cabeçalho List-Unsubscribe). O token (32 hex) é o HMAC do id do
# destinatário (Canal::Envios::envio_token_saida); o banco guarda só o
# sha256 dele em `canal_envio_destinatarios.saida_hash`.
#
# Saída = `canal_optouts (lista_id, 'email', email_hash, envio_id)` com a
# lista de ORIGEM do destinatário — por hash do e-mail, sem PII; sobrevive à
# anonimização. Idempotente (ON CONFLICT DO NOTHING): `ja_saiu` diz se o
# opt-out já existia. Envios futuros daquela lista (inclusive via lista
# dinâmica) pulam o endereço como `ignorado_optout`
# (Canal::Segmentos::resolver_destinatarios). Reinscrição pelo QR com o mesmo
# e-mail desfaz o opt-out (Canal::Listas::registrar_inscricao).
#
# Independe de `canais.inscricao.enabled` (direito do titular). Composta no
# model Canal; usa os helpers SQL de Canal::Listas.

requires qw(_rows _row);

sub saida_token_valido ($self, $token) {
  return defined $token && !ref $token && $token =~ /^[0-9a-fA-F]{32}\z/ ? 1 : 0;
}

# Destinatário do token. Devolve undef (formato inválido, inexistente ou
# lista de origem apagada) ou { destinatario_id, envio_id, lista_id,
# email_hash, cod_inep, escola_nome, lista_nome, ja_saiu }.
sub saida_por_token ($self, $token) {
  return unless $self->saida_token_valido($token);
  my $r = $self->_row(
    q{SELECT d.id, d.envio_id, d.lista_id, d.email_hash,
             l.cod_inep, l.nome AS lista_nome, e.escola AS escola_nome,
             EXISTS (SELECT 1 FROM clean.canal_optouts o
                      WHERE o.lista_id = d.lista_id AND o.canal = 'email'
                        AND o.email_hash = d.email_hash) AS ja_saiu
      FROM   clean.canal_envio_destinatarios d
      JOIN   clean.canal_listas l ON l.id = d.lista_id
      LEFT JOIN clean.escolas e  ON e.codigo_inep = l.cod_inep
      WHERE  d.saida_hash = ?},
    sha256_hex(lc $token),
  ) or return;
  return {
    destinatario_id => $r->{id} + 0,
    envio_id        => $r->{envio_id} + 0,
    lista_id        => $r->{lista_id} + 0,
    email_hash      => $r->{email_hash},
    cod_inep        => $r->{cod_inep} + 0,
    escola_nome     => $r->{escola_nome},
    lista_nome      => $r->{lista_nome},
    ja_saiu         => $r->{ja_saiu} ? 1 : 0,
  };
}

# Registra a saída (idempotente). Devolve undef (token inexistente) ou
# { ok => 1, ja_saiu => 0|1 }.
sub sair_por_token ($self, $token) {
  my $s = $self->saida_por_token($token) or return;
  my $ins = $self->_row(
    q{INSERT INTO clean.canal_optouts (lista_id, canal, email_hash, envio_id)
      VALUES (?, 'email', ?, ?)
      ON CONFLICT (lista_id, canal, email_hash) DO NOTHING
      RETURNING id},
    $s->{lista_id}, $s->{email_hash}, $s->{envio_id},
  );
  return { ok => 1, ja_saiu => $ins ? 0 : 1 };
}

1;
