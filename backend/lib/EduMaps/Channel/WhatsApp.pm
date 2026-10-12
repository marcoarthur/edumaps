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
#
# Confirmação de posse nas listas com QR (#212): com `template_confirmacao`
# configurado, o código vai por TEMPLATE DE AUTENTICAÇÃO da Meta (type
# template; body com o código e botão "copiar código" — sub_type url, index 0,
# com o mesmo código). Sem template, a confirmação continua por texto (uso
# genérico); a disponibilidade do canal nas listas exige o template
# (AppConfig::canais_confirmacao_disponiveis). Com template, o corpo gravado no
# histórico NÃO contém o código.

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

# Nome do template de autenticação configurado (ou undef).
sub template_confirmacao ($self) {
  my $t = $self->config->{template_confirmacao};
  return (defined $t && length $t) ? $t : undef;
}

sub template_idioma ($self) {
  my $l = $self->config->{template_idioma};
  return (defined $l && length $l) ? $l : 'pt_BR';
}

# Confirmação por template disponível: provedor cloud completo + template.
sub supports_template_confirm ($self) {
  return ($self->supports_confirm && $self->template_confirmacao) ? 1 : 0;
}

sub _confirm_template ($self, $codigo, %ctx) {
  # Com template, o texto é só o registro do histórico: sem o código.
  if (my $t = $self->template_confirmacao) {
    return "Código de confirmação enviado pelo template \"$t\".";
  }
  return "EduMaps: seu código de confirmação é $codigo. Ele expira em poucos minutos.";
}

# Payload da Cloud API para o template de autenticação com botão "copiar
# código" (formato padrão da Meta): o código vai no body e no botão url.
sub template_payload ($self, $to, $codigo) {
  return {
    messaging_product => 'whatsapp',
    to                => $to,
    type              => 'template',
    template          => {
      name       => $self->template_confirmacao,
      language   => { code => $self->template_idioma },
      components => [
        { type => 'body',
          parameters => [ { type => 'text', text => "$codigo" } ] },
        { type => 'button', sub_type => 'url', index => '0',
          parameters => [ { type => 'text', text => "$codigo" } ] },
      ],
    },
  };
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

  # Código de confirmação com template configurado → template de
  # autenticação; demais mensagens → texto.
  my $payload = (defined $msg->{codigo} && $self->template_confirmacao)
    ? $self->template_payload($msg->{to}, $msg->{codigo})
    : {
        messaging_product => 'whatsapp',
        to                => $msg->{to},
        type              => 'text',
        text              => { body => $self->_compose_text($msg) },
      };

  my $url = "https://graph.facebook.com/v20.0/$cfg->{phone_number_id}/messages";
  my $tx  = $self->ua->post($url, { Authorization => 'Bearer ' . $cfg->{token} } => json => $payload);

  if ($tx->res->is_success) {
    my $res  = { ok => 1, status => $tx->res->code };
    my $json = eval { $tx->res->json };
    $res->{provider_message_id} = $json->{messages}[0]{id}
      if ref $json eq 'HASH' && ref $json->{messages} eq 'ARRAY'
        && ref $json->{messages}[0] eq 'HASH';
    return $res;
  }
  my $err = $tx->error ? $tx->error->{message} : $tx->res->message;
  return { ok => 0, status => $tx->res->code // 0, error => $err };
}

1;
