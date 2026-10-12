package EduMaps::Channel::Email;
use Mojo::Base 'EduMaps::Channel::Base', -signatures;
use utf8;

# ============================================================================
# CANAL E-MAIL
# ============================================================================
#
# Valida e normaliza o endereço (domínio em minúsculas) e entrega via SMTP
# (Net::SMTP, núcleo do Perl; em TLS usa IO::Socket::SSL — ambos declarados
# no cpanfile por convenção do repo). As credenciais vêm de
# `canais.email.*` (Painel de Configuração; senha cifrada). Sem SMTP
# configurado a entrega falha com erro explícito — nunca silencioso.

# Transporte SMTP injetável (coderef `($cfg, $to, $from, $envelope) -> {ok,...}`):
# quando definido, substitui a transação Net::SMTP (testes e ambientes sem
# rede). O app o expõe pelo helper `canais_smtp` (Plugin::API::Canais).
has smtp_transport => undef;

sub name         { 'email' }
sub address_kind { 'email' }
sub max_len      { 254 }
sub supports_confirm { 1 }

sub _address_regex ($self) {
  return qr/^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;
}

sub _normalize_address ($self, $addr) {
  $addr =~ s/^\s+|\s+$//g;
  return lc $addr;
}

# %ctx opcional: `lista_nome`/`escola_nome` (contexto da inscrição) e
# `exclusao_info` (texto sobre como remover os dados — #214, RF-204).
sub _confirm_template ($self, $codigo, %ctx) {
  my $txt = "EduMaps\n\nSeu código de confirmação de e-mail é: $codigo\n\n";
  if (defined $ctx{lista_nome} && length $ctx{lista_nome}) {
    $txt .= "Inscrição na lista \"$ctx{lista_nome}\""
      . (defined $ctx{escola_nome} && length $ctx{escola_nome}
         ? " da escola $ctx{escola_nome}" : '')
      . ".\n\n";
  }
  $txt .= "Ele expira em poucos minutos. Se você não solicitou, ignore esta mensagem.";
  $txt .= "\n\n$ctx{exclusao_info}"
    if defined $ctx{exclusao_info} && length $ctx{exclusao_info};
  return $txt;
}

sub _deliver ($self, $msg) {
  my $cfg = $self->config // {};
  return { ok => 0, error => 'SMTP não configurado' }
    unless $cfg->{smtp_host} && $cfg->{from};

  my $from     = $cfg->{from};
  my $from_hdr = $cfg->{from_name}
    ? '"' . $self->_mime_word($cfg->{from_name}) . "\" <$from>"
    : $from;

  my $assunto = $self->_mime_word($msg->{assunto} // 'EduMaps');
  my $corpo   = $msg->{corpo} // '';

  my $envelope = join("\r\n",
    "From: $from_hdr",
    "To: $msg->{to}",
    "Subject: $assunto",
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    $corpo,
  ) . "\r\n";

  return $self->_smtp_transaction($cfg, $msg->{to}, $from, $envelope);
}

# Fronteira de teste: subclasse/objeto de teste pode sobrescrever para não
# abrir socket. Faz a transação SMTP de facto.
sub _smtp_transaction ($self, $cfg, $to, $from, $envelope) {
  if (my $tr = $self->smtp_transport) {
    my $res = eval { $tr->($cfg, $to, $from, $envelope) };
    return ref $res eq 'HASH' ? $res : { ok => 0, error => ($@ || 'falha no transporte SMTP') };
  }
  require Net::SMTP;
  my $port = $cfg->{smtp_port} // 25;
  my %args = (Port => $port, Timeout => 10);
  # 465 é SMTPS implícito; 587 usa STARTTLS depois de conectar. Ambos exigem
  # IO::Socket::SSL (declarado no cpanfile).
  require IO::Socket::SSL if $cfg->{smtp_tls};
  $args{SSL} = 1 if $cfg->{smtp_tls} && $port == 465;

  my $smtp = Net::SMTP->new($cfg->{smtp_host}, %args)
    or return { ok => 0, error => 'falha ao conectar ao servidor SMTP' };

  if ($cfg->{smtp_tls} && !$args{SSL}) {
    unless ($smtp->starttls) {
      $smtp->quit;
      return { ok => 0, error => 'STARTTLS recusado pelo servidor' };
    }
  }

  if ($cfg->{smtp_user}) {
    unless ($smtp->auth($cfg->{smtp_user}, $cfg->{smtp_password} // '')) {
      $smtp->quit;
      return { ok => 0, error => 'autenticação SMTP recusada' };
    }
  }

  for my $step (
    [ mail    => $from ],
    [ to      => $to   ],
    [ data    => undef ],
    [ datasend => $envelope ],
    [ dataend => undef ],
  ) {
    my ($method, $arg) = @$step;
    my $ok = defined $arg ? $smtp->$method($arg) : $smtp->$method;
    unless ($ok) {
      $smtp->quit;
      return { ok => 0, error => "SMTP: falha em $method" };
    }
  }
  $smtp->quit;
  return { ok => 1 };
}

# Codifica cabeçalhos com acento em MIME (ex.: assunto "Reunião").
sub _mime_word ($self, $text) {
  return $text unless defined $text && $text =~ /[^\x00-\x7F]/;
  require Encode;
  return Encode::encode('MIME-Header', $text);
}

1;
