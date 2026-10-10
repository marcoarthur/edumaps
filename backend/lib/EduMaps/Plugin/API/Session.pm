package EduMaps::Plugin::API::Session;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Endpoint público de telemetria: recebe o lote de eventos do navegador
# (middleware JS — etapa 2) e re-emite cada evento válido no EventBus
# (session.*), persistido em lote pelo EventLogger.
#
# Sem autenticação: identidade é a sessão (cookie edumaps_sid) + allowlist
# estrita de tipos/chaves no controller.

has session_path => '/api/session';

sub register ($self, $app, @args) {
  my $api = $app->routes->under($self->session_path);

  $api->post('/events')->to('session#events')->name('session_events');
}

1;