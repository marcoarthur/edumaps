package EduMaps::Bots::Role::Sender;
use Mojo::Base -role, -signatures;

# Interface mínima para envio de mensagens
requires 'send_text';

sub send_message ($self, $text, $opts = {}) {
  return $self->send_text($text, $opts);
}

1;
