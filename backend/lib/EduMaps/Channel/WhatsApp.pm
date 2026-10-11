package EduMaps::Channel::WhatsApp;
use Mojo::Base 'EduMaps::Channel::Base', -signatures;
use utf8;

use Mojo::URL;

# ============================================================================
# CANAL WHATSAPP
# ============================================================================
#
# Valida e normaliza o telefone brasileiro para o formato do WhatsApp
# (`55` + DDD + número). Dois provedores:
#   - `link`  (padrão): NÃO envia — devolve um link wa.me pronto a copiar
#     (stub), como o convite copiável que já existe no frontend.
#   - `cloud`: envia de facto via WhatsApp Cloud API (Meta).
#
# Confirmação só é possível com o provedor `cloud` (com token e número): no
# modo `link` não há entrega, logo não há como conferir a posse do número.

sub name         { 'whatsapp' }
sub address_kind { 'phone' }
sub max_len      { 20 }

sub _provider ($self) { return $self->config->{provider} // 'link' }

sub supports_confirm ($self) {
  return 0 unless $self->_provider eq 'cloud';
  return ($self->config->{token} && $self->config->{phone_number_id}) ? 1 : 0;
}

sub _address_regex ($self) { return qr/^55[1-9][0-9]\d{8,9}$/ }

sub _normalize_address ($self, $addr) {
  my $digits = $addr =~ s/\D//gr;
  return undef unless length $digits;
  $digits =~ s/^00//;
  # Sem o código do país, prefixa 55 (Brasil).
  $digits = "55$digits" unless $digits =~ /^55/ && length($digits) >= 12;
  return $digits;
}

sub _compose_text ($self, $msg) {
  my $prefix = defined $msg->{assunto} && length $msg->{assunto}
    ? "$msg->{assunto}\n\n" : '';
  return $prefix . ($msg->{corpo} // '');
}

sub _confirm_template ($self, $codigo, %ctx) {
  return "EduMaps: seu código de confirmação é $codigo. Ele expira em poucos minutos.";
}

sub _deliver ($self, $msg) {
  return $self->_deliver_cloud($msg) if $self->_provider eq 'cloud';

  # Modo link (stub): não entrega; gera o link wa.me com o texto pronto.
  my $texto = $self->_compose_text($msg);
  my $link  = Mojo::URL->new("https://wa.me/$msg->{to}")->query(text => $texto)->to_string;
  return { ok => 1, provider => 'link', stub => 1, wa_link => $link };
}

sub _deliver_cloud ($self, $msg) {
  my $cfg = $self->config // {};
  return { ok => 0, error => 'WhatsApp Cloud: token ausente' } unless $cfg->{token};
  return { ok => 0, error => 'WhatsApp Cloud: número ausente' } unless $cfg->{phone_number_id};

  my $url = "https://graph.facebook.com/v20.0/$cfg->{phone_number_id}/messages";
  my $tx  = $self->ua->post($url, { Authorization => 'Bearer ' . $cfg->{token} } => json => {
    messaging_product => 'whatsapp',
    to                => $msg->{to},
    type              => 'text',
    text              => { body => $self->_compose_text($msg) },
  });

  return { ok => 1, status => $tx->res->code } if $tx->res->is_success;
  my $err = $tx->error ? $tx->error->{message} : $tx->res->message;
  return { ok => 0, status => 0, error => $err };
}

1;
