package EduMaps::Channel::Telegram;
use Mojo::Base 'EduMaps::Channel::Base', -signatures;
use utf8;

use Mojo::Promise;

# ============================================================================
# CANAL TELEGRAM
# ============================================================================
#
# Reutiliza o bot já existente (EduMaps::Bots::Telegram) para a entrega — sem
# reimplementar HTTP nem mapeamento de resposta (DRY). O destino é um `chat_id`
# (numérico, possivelmente negativo para grupos) ou um `@username`. O token vem
# da config do bot (`integrations.bot_telegram.token`, via AppConfig).

sub name         { 'telegram' }
sub address_kind { 'chat_id' }
sub supports_confirm { 1 }
sub max_len      { 64 }

has bot_class => 'EduMaps::Bots::Telegram';

sub _address_regex ($self) {
  return qr/^(?:-?\d{1,20}|@[A-Za-z][A-Za-z0-9_]{4,31})$/;
}

sub _normalize_address ($self, $addr) {
  $addr =~ s/^\s+|\s+$//g;
  # Link t.me/username -> @username (a forma canônica de usuário).
  if ($addr =~ s{^https?://t\.me/}{}i) {
    $addr = '@' . $addr unless $addr =~ /^[-0-9@]/;
  }
  return $addr;
}

sub _compose_text ($self, $msg) {
  my $prefix = defined $msg->{assunto} && length $msg->{assunto}
    ? "$msg->{assunto}\n\n" : '';
  return $prefix . ($msg->{corpo} // '');
}

sub _confirm_template ($self, $codigo, %ctx) {
  return "EduMaps — seu código de confirmação é $codigo. Ele expira em poucos minutos.";
}

sub _bot ($self) {
  require EduMaps::Bots::Telegram;
  return $self->bot_class->new(
    config => { telegram_token => $self->config->{token} // '' },
    # o UA do canal (injetável em teste) é o do bot
    ua     => $self->ua,
  );
}

# Opções de envio: chat_id e, opcionalmente, o teclado (`reply_markup`) do bot
# público da confirmação de posse (#212).
sub _send_opts ($self, $msg) {
  my %o = (chat_id => $msg->{to});
  $o{reply_markup} = $msg->{reply_markup} if ref $msg->{reply_markup};
  return \%o;
}

sub _deliver ($self, $msg) {
  return { ok => 0, error => 'Telegram: token ausente' }
    unless length($self->config->{token} // '');
  return $self->_bot->send_text($self->_compose_text($msg), $self->_send_opts($msg));
}

sub _deliver_p ($self, $msg) {
  return Mojo::Promise->resolve({ ok => 0, error => 'Telegram: token ausente' })
    unless length($self->config->{token} // '');
  return $self->_bot->send_text_p($self->_compose_text($msg), $self->_send_opts($msg));
}

1;
