package EduMaps::Plugin::API::Pesquisa;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Pesquisas do gestor (fase 1): cadastro do gestor + CRUD de pesquisas.
# O gestor não tem login — a sessão é um upsert por e-mail em /perfil.

has pesquisas_path => '/api/gestor/pesquisas';

sub register ($self, $app, @args) {
  my $api = $app->routes->under($self->pesquisas_path);
  my $with_id = { id => qr/\d+/ };

  $api->post('/perfil')->to('pesquisa#perfil')->name('pesquisa_gestor_perfil');
  $api->get('/')->to('pesquisa#index')->name('pesquisas_index');
  $api->post('/')->to('pesquisa#create')->name('pesquisas_create');
  $api->get('/:id'        => $with_id)->to('pesquisa#show')->name('pesquisa_show');
  $api->put('/:id'        => $with_id)->to('pesquisa#update')->name('pesquisa_update');
  $api->post('/:id/finalizar' => $with_id)->to('pesquisa#finalize')->name('pesquisa_finalize');
  $api->delete('/:id'     => $with_id)->to('pesquisa#destroy')->name('pesquisa_destroy');
}

1;