package EduMaps::Controller::Session;
use Mojo::Base 'EduMaps::Controller::Base', -signatures;
use utf8;

# ============================================================================
# TELEMETRIA — ENDPOINT DE EVENTOS DO NAVEGADOR (etapa 1)
# ============================================================================
#
# `POST /api/session/events` recebe um array de eventos do cliente e
# re-emite no EventBus apenas os tipos da ALLOWLIST, copiando SÓ as chaves
# declaradas — o resto do payload do navegador (ex.: texto digitado) é
# descartado no servidor. Cada evento válido torna-se um evento `session.*`
# no bus, persistido em lote pelo EventLogger (event_store + session_tracking).
#
# Fogo-e-esqueça: devolve 204 imediato; nenhum acesso a banco aqui.
# ============================================================================

has max_batch => 200;

# tipo do cliente -> evento do EventBus + chaves aceitas do payload
has type_map => sub { {
  'navigate'       => { type => 'session.navigate',  keys => [qw(route)] },
  'schools:search' => { type => 'session.search',    keys => [qw(q_len result_count)] },
  'gestor:login'   => { type => 'session.login',     keys => [qw(ok)] },
  'gestor:logout'  => { type => 'session.logout',    keys => [] },
  'api:error'      => { type => 'session.api_error', keys => [qw(status route)] },
} };

sub events ($self) {
  my $body = $self->req->json;
  return $self->bad_req('esperava um array de eventos') unless ref $body eq 'ARRAY';
  return $self->bad_req('lote de eventos grande demais') if @$body > $self->max_batch;

  my $session = $self->stash('session') // {};
  my $sid     = $session->{id};

  for my $ev (@$body) {
    next unless ref $ev eq 'HASH';
    my $rule = $self->type_map->{ $ev->{type} // '' } or next;

    my $client = ref $ev->{payload} eq 'HASH' ? $ev->{payload} : {};
    my %clean;
    $clean{$_} = $client->{$_} for @{ $rule->{keys} };   # allowlist de chaves
    $clean{session_id} = $sid if defined $sid && length $sid;

    my $ts = $ev->{ts};
    $clean{ts} = $ts if defined $ts && $ts =~ /^\d{1,13}$/;

    $self->app->event_bus->emit($rule->{type}, \%clean, source => 'frontend');
  }

  $self->render(status => 204, text => '');
}

1;

__END__

=head1 NAME

EduMaps::Controller::Session - endpoint de eventos de telemetria do navegador

=head1 ROUTE

B<POST /api/session/events> — corpo: array de eventos

  [{ "type": "navigate", "ts": 1720000000000, "payload": { "route": "/" } }]

Tipos aceitos (allowlist): C<navigate>, C<schools:search> (sem texto — só
C<q_len>/C<result_count>), C<gestor:login>, C<gestor:logout>, C<api:error>.

=head1 LGPD

O texto digitado e qualquer chave fora da allowlist são descartados no
servidor. Nenhum dado pessoal é gravado a partir deste endpoint (o IP fica
na dimensão de sessão, tratado pelo EventLogger).

=cut