package EduMaps::Plugin::API::Admin;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Rotas administrativas da plataforma (Painel de Configuração). Exige sessão
# de gestor com papel admin (Bearer — under com gestor#_require_admin).

has admin_path => '/api/admin';

sub register ($self, $app, @args) {
  my $key_re = [ key => qr/[a-z0-9_.]+/ ];

  my $auth = $app->routes->under($self->admin_path)->to('gestor#_require_admin');

  # /config/tree antes de /config/:key para não colidir na especificidade.
  $auth->get('/config/tree')->to('admin#config_tree')->name('admin_config_tree');
  $auth->get('/config/:key' => $key_re)->to('admin#config_show')->name('admin_config_show');
  $auth->put('/config/:key' => $key_re)->to('admin#config_update')->name('admin_config_update');
  $auth->post('/config/:key/validate' => $key_re)->to('admin#config_validate')->name('admin_config_validate');
}

1;