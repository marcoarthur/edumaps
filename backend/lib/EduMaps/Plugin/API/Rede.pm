package EduMaps::Plugin::API::Rede;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Visão da rede (#394, #375). Convite: anônimo, com limite de tentativas por
# IP (pesquisa#rede_convite_*). Demais rotas: sessão com papel `rede`.

has rede_path => '/api/rede';

sub register ($self, $app, @args) {
  my $token = [ token => qr/[A-Za-z0-9_-]{43}/ ];

  my $publico = $app->routes->under($self->rede_path);
  $publico->get('/convite/:token' => $token)->to('pesquisa#rede_convite_show')->name('rede_convite_show');
  $publico->post('/convite/:token' => $token)->to('pesquisa#rede_convite_aceitar')->name('rede_convite_aceitar');

  my $auth = $app->routes->under($self->rede_path)->to('gestor#_require_rede');
  $auth->get('/me')->to('rede#me')->name('rede_me');
  $auth->get('/escolas')->to('rede#escolas')->name('rede_escolas');
  $auth->get('/escolas/:cod_inep' => [ cod_inep => qr/\d{8}/ ])->to('rede#escola')->name('rede_escola');
}

1;
