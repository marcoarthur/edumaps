package EduMaps::Plugin::API::Pesquisa;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Pesquisas do gestor.
#   Fase 1: cadastro do gestor + CRUD de pesquisas (sessão por e-mail em /perfil).
#   Fase 2: login do gestor (POST /api/gestor/login), link público de resposta
#   (GET/POST /api/gestor/pesquisas/publica/:token) e resultados
#   (GET /:id/resultados — exige sessão do gestor da escola).

has pesquisas_path => '/api/gestor/pesquisas';

sub register ($self, $app, @args) {
  # --- rotas anônimas de gestão (fase 1) -----------------------------
  my $api = $app->routes->under($self->pesquisas_path);
  my $with_id    = { id => qr/\d+/ };
  my $with_token = { token => qr/[0-9a-fA-F-]{36}/ };

  $api->post('/perfil')->to('pesquisa#perfil')->name('pesquisa_gestor_perfil');
  $api->get('/')->to('pesquisa#index')->name('pesquisas_index');
  $api->post('/')->to('pesquisa#create')->name('pesquisas_create');

  # --- link público de resposta (fase 2, sem autenticação) ------------
  # Registrado ANTES das rotas :id para ganhar na especificidade.
  $api->get('/publica/:token'      => $with_token)->to('pesquisa#publica_form')->name('pesquisa_publica_form');
  $api->post('/publica/:token/resposta' => $with_token)->to('pesquisa#publica_resposta')->name('pesquisa_publica_resposta');

  $api->get('/:id'        => $with_id)->to('pesquisa#show')->name('pesquisa_show');
  $api->put('/:id'        => $with_id)->to('pesquisa#update')->name('pesquisa_update');
  $api->post('/:id/finalizar' => $with_id)->to('pesquisa#finalize')->name('pesquisa_finalize');
  $api->delete('/:id'     => $with_id)->to('pesquisa#destroy')->name('pesquisa_destroy');

  # --- autenticação do gestor (fase 2) --------------------------------
  my $public = $app->routes->under('/api/gestor');
  $public->post('/login')->to('pesquisa#login')->name('gestor_login');

  my $sessao = $app->routes->under('/api/gestor')->to('pesquisa#_require_gestor');
  $sessao->get('/me')->to('pesquisa#me')->name('gestor_me');
  $sessao->post('/logout')->to('pesquisa#logout')->name('gestor_logout');

  # resultados exigem sessão do gestor da escola
  my $signed = $app->routes->under($self->pesquisas_path)->to('pesquisa#_require_gestor');
  $signed->get('/:id/resultados' => $with_id)->to('pesquisa#resultados')->name('pesquisa_resultados');
}

1;