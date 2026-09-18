package EduMaps::Plugin::API::Gestor;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Rotas do painel do gestor escolar. Módulo isolado: não altera os plugins
# de API pré-existentes (School, City, Rank, ...).

has gestor_path => '/api/gestor';

sub register($self, $app, @args) {
  my $api = $app->routes->under($self->gestor_path);

  my $check = [cod_inep => qr/\d{8}/];

  $api->get('/:cod_inep/painel' => $check)->to('gestor#panel')->name('gestor_panel');
}

1;
