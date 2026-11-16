package EduMaps::Plugin::API::BaseAnalise;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

# Base de análise (#439): exportação pública, sem login, uma UF por vez.
sub register ($self, $app, @args) {
  my $r = $app->routes;
  $r->get('/api/base-analise')->to('base_analise#index')->name('base_analise');
  $r->get('/api/base-analise/csv')->to('base_analise#csv')->name('base_analise_csv');
  $r->get('/api/base-analise/dicionario')->to('base_analise#dicionario')->name('base_analise_dicionario');
}

1;
