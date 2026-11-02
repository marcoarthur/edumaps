package EduMaps::Plugin::API::Pesquisa;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Pesquisas do gestor.
#   Anônimas: cadastro do gestor (/perfil, só cria conta), login e o link
#   público de resposta (GET/POST /api/gestor/pesquisas/publica/:token).
#   Com sessão do gestor: CRUD das pesquisas e resultados, sempre da escola
#   da sessão.

has pesquisas_path => '/api/gestor/pesquisas';

sub register ($self, $app, @args) {
  # --- rotas anônimas ------------------------------------------------
  my $api = $app->routes->under($self->pesquisas_path);
  my $with_id    = { id => qr/\d+/ };
  my $with_token = { token => qr/[0-9a-fA-F-]{36}/ };

  $api->post('/perfil')->to('pesquisa#perfil')->name('pesquisa_gestor_perfil');

  # link público de resposta (sem autenticação)
  $api->get('/publica/:token'      => $with_token)->to('pesquisa#publica_form')->name('pesquisa_publica_form');
  $api->post('/publica/:token/resposta' => $with_token)->to('pesquisa#publica_resposta')->name('pesquisa_publica_resposta');

  # --- autenticação do gestor (fase 2) --------------------------------
  my $public = $app->routes->under('/api/gestor');
  $public->post('/login')->to('pesquisa#login')->name('gestor_login');

  # esqueci minha senha (#336) — anônimas
  $public->get('/senha/disponivel')->to('pesquisa#senha_disponivel')->name('gestor_senha_disponivel');
  $public->post('/senha/esqueci')->to('pesquisa#senha_esqueci')->name('gestor_senha_esqueci');
  $public->post('/senha/redefinir')->to('pesquisa#senha_redefinir')->name('gestor_senha_redefinir');

  my $sessao = $app->routes->under('/api/gestor')->to('pesquisa#_require_gestor');
  $sessao->get('/me')->to('pesquisa#me')->name('gestor_me');
  $sessao->post('/logout')->to('pesquisa#logout')->name('gestor_logout');

  # --- gestão das pesquisas: sessão do gestor, escola da sessão --------
  my $signed = $app->routes->under($self->pesquisas_path)->to('pesquisa#_require_gestor');
  $signed->get('/')->to('pesquisa#index')->name('pesquisas_index');
  $signed->post('/')->to('pesquisa#create')->name('pesquisas_create');
  $signed->get('/:id'        => $with_id)->to('pesquisa#show')->name('pesquisa_show');
  $signed->put('/:id'        => $with_id)->to('pesquisa#update')->name('pesquisa_update');
  $signed->post('/:id/finalizar' => $with_id)->to('pesquisa#finalize')->name('pesquisa_finalize');
  $signed->delete('/:id'     => $with_id)->to('pesquisa#destroy')->name('pesquisa_destroy');
  $signed->get('/:id/resultados' => $with_id)->to('pesquisa#resultados')->name('pesquisa_resultados');
}

1;