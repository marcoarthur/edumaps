package EduMaps::Bots::Telegram;
use Mojo::Base 'EduMaps::Bots::Base', -signatures;
use Role::Tiny::With;

use Mojo::UserAgent;
use Mojo::URL;

with 'EduMaps::Bots::Role::Sender';

has name => 'telegram';
has ua   => sub { Mojo::UserAgent->new(timeout => 10) };

sub can_receive { return 0 }

# Envio síncrono (bloqueante): usado pelo endpoint admin de teste
# (POST /api/admin/bot/telegram/test) e pelo Notifier em contexto sem loop.
sub send_text ($self, $text, $opts = {}) {
  my $tx = $self->_post_tx($text, $opts);
  return $self->_map_response($tx);
}

# Envio assíncrono (Mojo::Promise, post_p não-bloqueante): usado pela
# fronteira assíncrona do Middleware::Bot quando há loop rodando (web/Minion).
# Nunca rejeita — resolve sempre { ok, status, error }.
sub send_text_p ($self, $text, $opts = {}) {
  my ($url, $form) = $self->_build_request($text, $opts);

  return $self->ua->post_p($url => json => $form)->then(
    sub ($tx) { $self->_map_response($tx) },
    sub ($err) { { ok => 0, status => 0, error => "$err" } },
  );
}

sub _post_tx ($self, $text, $opts) {
  my ($url, $form) = $self->_build_request($text, $opts);
  return $self->ua->post($url => json => $form);
}

sub _build_request ($self, $text, $opts) {
  my $token   = $opts->{token}   // $self->config->{telegram_token}   // '';
  my $chat_id = $opts->{chat_id} // $self->config->{telegram_chat_id} // '';
  $chat_id = $opts->{chat_id} if defined $opts->{chat_id};
  die "Telegram: token em falta\n"   unless length($token // '');
  die "Telegram: chat_id em falta\n" unless length($chat_id // '');

  my $url  = "https://api.telegram.org/bot$token/sendMessage";
  my $form = { chat_id => $chat_id, text => $text };
  return ($url, $form);
}

sub _map_response ($self, $tx) {
  if ($tx->res->is_success) {
    return { ok => 1, status => $tx->res->code };
  }
  # Falha de conexão vs recusa HTTP: `res` fica vazio (code/message undef) e
  # a causa real está em $tx->error — não perder o diagnóstico.
  my $conn = $tx->error;
  if ($conn) {
    return { ok => 0, status => 0, error => $conn->{message} };
  }
  return { ok => 0, status => $tx->res->code, error => $tx->res->message };
}

# Estrutura preparada para receber (fase futura), não ativada na fase 1
sub receive_updates ($self, $opts = {}) {
  die "Telegram: recebimento não habilitado na fase 1\n";
}

1;
