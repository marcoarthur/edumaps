package EduMaps::Bots::Telegram;
use Mojo::Base 'EduMaps::Bots::Base', -signatures;
use Role::Tiny::With;

use Mojo::UserAgent;
use Mojo::URL;

with 'EduMaps::Bots::Role::Sender';

has name => 'telegram';
has ua   => sub { Mojo::UserAgent->new(timeout => 10) };

sub can_receive { return 0 }

sub send_text ($self, $text, $opts = {}) {
  my $token   = $opts->{token}   // $self->config->{telegram_token}   // '';
  my $chat_id = $opts->{chat_id} // $self->config->{telegram_chat_id} // '';
  $chat_id = $opts->{chat_id} if defined $opts->{chat_id};
  die "Telegram: token em falta\n"   unless length($token // '');
  die "Telegram: chat_id em falta\n" unless length($chat_id // '');

  my $url = "https://api.telegram.org/bot$token/sendMessage";
  my $tx = $self->ua->post($url => json => {
    chat_id => $chat_id,
    text    => $text,
  });
  if ($tx->res->is_success) {
    return { ok => 1, status => $tx->res->code };
  }
  return { ok => 0, status => $tx->res->code, error => $tx->res->message };
}

# Estrutura preparada para receber (fase futura), não ativada na fase 1
sub receive_updates ($self, $opts = {}) {
  die "Telegram: recebimento não habilitado na fase 1\n";
}

1;
