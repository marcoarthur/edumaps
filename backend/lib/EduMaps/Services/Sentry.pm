package EduMaps::Services::Sentry;
use Mojo::Base -base, -signatures;

use Mojo::IOLoop;
use Mojo::JSON qw(encode_json);
use Mojo::UserAgent;
use Scalar::Util qw(blessed);

# ABSTRACT: Thin client para a Sentry Envelope API (sentry.io cloud)

# Cliente enxuto de observabilidade: envia "envelopes" (eventos de erro)
# para a Sentry API sem nenhuma dependência CPAN extra (só Mojolicious/Mojo).
#
# Sem `dsn` o serviço é um no-op silencioso: `capture_exception`/
# `capture_message` retornam imediatamente e nenhum hook é registrado
# (configuração local/dev sem conta sentry.io não quebra nada).
#
# Privacidade (LGPD): `send_default_pii => 0` é decisão do SDK de captura
# (frontend); aqui NUNCA enviamos corpo de request nem argumentos sensíveis
# de job — `_sanitize_args` derruba CPF/CNPJ/salários/tokens e valores
# longos (usar a allow-list dos callers para o que é permitido).

has dsn         => '';
has ua          => sub { Mojo::UserAgent->new(connect_timeout => 3, inactivity_timeout => 5) };
has log         => sub { Mojo::Log->new };
has environment => 'development';
has release     => '';
has server_name => sub { $ENV{EDUMAPS_SENTRY_SERVER} || eval { require Sys::Hostname; Sys::Hostname::hostname() } || '' };

sub is_active ($self) { !!$self->dsn }

# Regex dos argumentos de job que nunca sobem ao Sentry (dados SIOPE contêm
# CPF/salários; tokens/segredos também). Valores posicionais com 11+ dígitos
# seguidos são tratados como CPF/CNPJ e descartados.
my $SENSITIVE_ARG = qr/(?:cpf|cnpj|senha|password|token|secret|salario|salary|remuneracao|matricula)/i;
my $LONG_DIGITS   = qr/\b\d{11,}\b/;

sub capture_exception ($self, $err, %ctx) {
  return unless $self->is_active;
  my $event = $self->_base_event(%ctx);
  my $e = blessed $err && $err->isa('Mojo::Exception') ? $err : Mojo::Exception->new("$err");
  $event->{message}   = $e->message;
  $event->{exception} = $self->_exception_payload($e);
  return $self->_send($event);
}

sub capture_message ($self, $message, %ctx) {
  return unless $self->is_active;
  my $event = $self->_base_event(%ctx);
  $event->{message} = $message;
  return $self->_send($event);
}

# Sanitiza argumentos posicionais de job para irem em `extra.args`.
# Retorna arrayref de {index => N, value => "str"} — só valores curtos e
# sem indícios de dado pessoal/sensível. Máx. 10 argumentos.
sub _sanitize_args ($self, $args) {
  return [] unless ref $args eq 'ARRAY';
  my @out;
  for my $i (0 .. $#$args) {
    my $v = $args->[$i];
    next unless defined $v;
    my $str = ref $v eq 'HASH' || ref $v eq 'ARRAY' ? encode_json($v) : "$v";
    next if $str =~ $SENSITIVE_ARG || $str =~ $LONG_DIGITS || length($str) > 200;
    push @out, { index => $i, value => $str };
    last if @out == 10;
  }
  return \@out;
}

sub _base_event ($self, %ctx) {
  my %tags;
  for my $k (sort keys %ctx) {
    next if $k eq 'level' || $k eq 'extra';
    next unless defined $ctx{$k};
    $tags{$k} = "$ctx{$k}";
  }
  my $event = {
    event_id    => $self->_event_id,
    timestamp   => $self->_timestamp,
    platform    => 'perl',
    level       => $ctx{level} || 'error',
    environment => $self->environment,
    release     => $self->release,
    server_name => $self->server_name,
    tags        => \%tags,
  };
  $event->{extra} = $ctx{extra} if $ctx{extra} && ref $ctx{extra} eq 'HASH';
  return $event;
}

# event_id de 32 hex. Não depende de export de `Mojo::Util::random_bytes`
# (incompatível com versões mais antigas do Mojolicious no carton): lê 16
# bytes de /dev/urandom (core), com fallback puramente local p/ testes/dev.
sub _event_id ($self) {
  my $bytes = '';
  if (open my $fh, '<', '/dev/urandom') {
    read($fh, $bytes, 16);
    close $fh;
  }
  $bytes .= chr(int(rand(256))) while length($bytes) < 16;
  return unpack 'H*', $bytes;
}

sub _timestamp ($self) {
  my ($s, $m, $h, $d, $mon, $y) = gmtime(time);
  return sprintf '%04d-%02d-%02dT%02d:%02d:%02dZ', $y + 1900, $mon + 1, $d, $h, $m, $s;
}

sub _exception_payload ($self, $e) {
  my $value = defined $e->message ? $e->message : 'Erro sem mensagem';
  $value =~ s/\s+\z//;
  my %entry = (type => ref $e || 'Exception', value => $value);
  my $frames = eval { $e->frames };
  if (ref $frames eq 'ARRAY' && @$frames) {
    my @out = map {
      my ($pkg, $file, $line, $sub) = @$_;
      { filename => $file || $pkg || '?', lineno => $line || 0, function => $sub || $pkg || '?' }
    } @$frames;
    $entry{stacktrace} = { frames => \@out };
  }
  return { values => [\%entry] };
}

# URL de ingestão a partir do DSN público (formato sentry.io cloud):
#   https://<public_key>@[o<org>.ingest.]sentry.io/<project>
#   => https://<host>/api/<project>/envelope/
sub _ingest_url ($self) {
  my $dsn = $self->dsn || return '';
  return '' unless (my ($scheme, $host, $project) = $dsn =~ m{^([a-z][a-z0-9+.-]*)://[^@/]*@?([^/]+)/([^/?#]+)}i);
  return "$scheme://$host/api/$project/envelope/";
}

sub _build_envelope ($self, $event) {
  my $json   = encode_json($event);
  my $header = encode_json({ event_id => $event->{event_id}, sent_at => $event->{timestamp}, dsn => $self->dsn });
  my $item   = encode_json({ type => 'event', content_type => 'application/json', length => length($json) });
  return "$header\n$item\n$json";
}

sub _send ($self, $event) {
  return unless $self->is_active;
  my $url = $self->_ingest_url;
  return unless $url;
  my $envelope = $self->_build_envelope($event);
  my $headers  = { 'content-type' => 'application/x-sentry-envelope' };
  eval {
    if (Mojo::IOLoop->is_running) {
      # Loop rodando (web server, pai do worker minion): fire-and-forget.
      # O envio acontece quando o loop voltar a girar; nunca bloqueia o request.
      $self->ua->post_p($url => $headers => $envelope)
        ->catch(sub ($err) { $self->log->warn("Sentry: envio falhou: $err") });
    }
    else {
      # Contexto síncrono (job minion/tests): bloqueia até enviar
      # (padrão Analytics::Client / Services::OSM).
      my $tx = $self->ua->post($url => $headers => $envelope);
      $self->log->warn('Sentry: HTTP ' . ($tx->res->code // '?') . " ao enviar envelope") if $tx->res->is_error;
    }
  };
  $self->log->warn("Sentry: erro ao enviar envelope: $@") if $@;
  return;
}

1;

__END__

=head1 NAME

EduMaps::Services::Sentry - Cliente enxuto da Sentry Envelope API

=head1 SYNOPSIS

  my $sentry = EduMaps::Services::Sentry->new(
    dsn         => 'https://<key>@o<org>.ingest.sentry.io/<project>',
    release     => 'abc1234',
    environment => 'development',
  );

  $sentry->capture_exception($e, task => 'siope', job_id => 42);
  $sentry->capture_message('HTTP 503 em /api/x');

=head1 DESCRIPTION

Envia erros para a sentry.io (cloud) via Envelope API em L<https://develop.sentry.dev/sdk/envelopes/>.
Sem `dsn` todas as operações são no-op.

=cut