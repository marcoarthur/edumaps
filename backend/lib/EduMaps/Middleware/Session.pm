package EduMaps::Middleware::Session;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use Time::HiRes qw(time);

# ============================================================================
# MIDDLEWARE DE SESSÃO (telemetria — etapa 1)
# ============================================================================
#
# Identifica o visitante por COOKIE de sessão gerado no servidor
# (`edumaps_sid`, HttpOnly + SameSite=Lax) e registra cada request `/api/*`
# como um evento `session.request` no EventBus — que é persistido EM LOTE
# pelo EventLogger (nunca um insert por request).
#
# Anônimos e gestores logados (Bearer token → stash `gestor`) caem na mesma
# dimensão `session_tracking`: IP/User-Agent/referer no stash, `gestor_id`
# preenchido quando a rota autenticada resolveu a identidade.
#
# Custos: nenhum acesso a banco por request — só leitura de cookie, stash e
# emit em memória. O cookie é setado apenas no primeiro contato (quando
# ausente), para não reescrever Set-Cookie em todo request.
#
# REGISTRO: precisa estar ANTES do Cache::SchoolSearch (ver EduMaps.pm) — o
# cache curto-circuita o around_dispatch em HIT (não chama $next), então um
# middleware registrado depois dele perde os requests servidos do cache.
# ============================================================================

has cookie_name    => 'edumaps_sid';
has cookie_max_age => 31536000;                 # 1 ano (identidade do visitante)
has api_prefix     => '/api/';
has skip_paths     => sub { ['/api/session/'] }; # endpoint de eventos não se loga a si mesmo
has ip_header      => 'X-Real-IP';               # nginx já propaga (frontend/nginx.conf)

sub register ($self, $app, $conf = {}) {
  $self->cookie_name($conf->{cookie_name})    if $conf->{cookie_name};
  $self->cookie_max_age($conf->{cookie_max_age}) if defined $conf->{cookie_max_age};
  $self->ip_header($conf->{ip_header})        if $conf->{ip_header};

  $app->hook(
    around_dispatch => sub ($next, $c) {
      my $sid = $self->_resolve_session($c);
      my $ip  = $self->_client_ip($c);

      # Contexto de sessão disponível para toda a cadeia (controllers,
      # middlewares, handlers do EventBus).
      $c->stash(
        session => {
          id         => $sid,
          ip         => $ip,
          user_agent => $c->req->headers->user_agent,
          referer    => $c->req->headers->referrer,
        }
      );

      my $start = time();
      $next->();

      # Identidade do gestor logado: definida em dispatch pelos under()
      # autenticados (_require_gestor). Sem novo acesso a banco.
      # Atenção: $c->stash(...) é sub call (não-lvalue) — nunca usar //= sobre
      # ela (`Can't modify non-lvalue subroutine call`); mutar via variável.
      my $session = $c->stash('session') // {};
      my $gestor  = $c->stash('gestor');
      if ($gestor && $gestor->{id}) {
        $session->{gestor_id} = $gestor->{id};
        $c->stash(session => $session);
      }

      $self->_emit_request_event($c, $start);
    }
  );
}

sub _resolve_session ($self, $c) {
  my $sid = $c->cookie($self->cookie_name);
  return $sid if defined $sid && length $sid && length($sid) <= 128;

  my $generated = $self->_gen_id;
  $c->cookie(
    $self->cookie_name => $generated,
    {
      path     => '/',
      max_age  => $self->cookie_max_age,
      httponly => 1,
      samesite => 'Lax',
    }
  );
  return $generated;
}

sub _gen_id ($self) {
  open my $fh, '<', '/dev/urandom' or die "sem /dev/urandom: $!";
  read $fh, my $bytes, 16;
  close $fh;
  return unpack('H*', $bytes);
}

sub _client_ip ($self, $c) {
  my $ip = $c->req->headers->header($self->ip_header) // $c->tx->remote_address;
  return $ip if defined $ip && $ip =~ /^[A-Fa-f0-9:.]+$/;
  return;
}

sub _emit_request_event ($self, $c, $start) {
  my $path = $c->req->url->path->to_string;
  return if index($path, $self->api_prefix) != 0;
  for my $skip (@{ $self->skip_paths }) {
    return if index($path, $skip) == 0;
  }

  my $app  = $c->app;
  return unless $app && $app->event_bus;

  my $session = $c->stash('session') // {};
  my $route = 'unknown';
  if (my $endpoint = $c->match->endpoint) {
    $route = $endpoint->name // $path;
  }
  elsif ($path) {
    # Cache HIT (Cache::SchoolSearch curto-circuita o dispatch): não há
    # endpoint resolvido — usa o path em vez de perder a rota na telemetria.
    $route = $path;
  }

  $app->event_bus->emit(
    'session.request',
    {
      session_id  => $session->{id},
      ip          => $session->{ip},
      user_agent  => $session->{user_agent},
      gestor_id   => $session->{gestor_id},
      route       => $route,
      method      => $c->req->method,
      status      => $c->res->code,
      duration_ms => int((time() - $start) * 1000),
    },
    source => __PACKAGE__,
  );
}

1;

__END__

=head1 NAME

EduMaps::Middleware::Session - identifica o visitante e registra requests /api/*

=head1 SYNOPSIS

  # EduMaps.pm (startup)
  $self->plugin("EduMaps::Middleware::Session");

=head1 CONFIG

=over

=item * cookie_name — nome do cookie de sessão (default edumaps_sid)

=item * cookie_max_age — Max-Age em segundos (default 1 ano)

=item * ip_header — header de IP confiável (default X-Real-IP, setado pelo nginx)

=item * skip_paths — prefixos de path que não geram session.request

=back

=head1 LGPD

Só guarda o IP na dimensão de sessão (propagado no payload para o
EventLogger, que o mantém fora do event_store e anonimiza em ip_anon).

=cut