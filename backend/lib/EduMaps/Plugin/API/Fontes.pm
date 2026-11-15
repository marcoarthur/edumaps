package EduMaps::Plugin::API::Fontes;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

# Fontes e metodologia (#428): catálogo público, sem login.
sub register ($self, $app, @args) {
  $app->routes->get('/api/fontes')->to('fontes#index')->name('fontes');
}

1;
