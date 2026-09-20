package EduMaps::Plugin::API::Gestor;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# Rotas do painel do gestor escolar. Módulo isolado: não altera os plugins
# de API pré-existentes (School, City, Rank, ...).
#
# Sub-módulo Reuniões e Atas: exige sessão do gestor (Bearer — under com
# gestor#_require_gestor) e o cod_inep da rota precisa ser o da escola logada.

has gestor_path => '/api/gestor';

sub register($self, $app, @args) {
  my $api = $app->routes->under($self->gestor_path);

  my $check = [ cod_inep => qr/\d{8}/ ];
  my $rid   = [ id => qr/\d+/ ];
  my $tipo  = [ tipo => qr/pauta|ata/ ];

  # Painel (público — dados do Censo; sem PII).
  $api->get('/:cod_inep/painel' => $check)->to('gestor#panel')->name('gestor_panel');
  $api->get('/:cod_inep/similares' => $check)->to('gestor#similares')->name('gestor_similares');

  # Autenticação (mesma sessão de /api/gestor/login — registrado no
  # Plugin::API::Pesquisa): /me e /logout também ficam aqui.
  my $sessao = $app->routes->under($self->gestor_path)->to('gestor#_require_gestor');
  $sessao->get('/me')->to('gestor#me')->name('gestor_me');
  $sessao->post('/logout')->to('gestor#logout')->name('gestor_logout');

  # Módulo Reuniões e Atas (agenda PII do gestor da escola).
  my $auth = $app->routes->under($self->gestor_path)->to('gestor#_require_gestor');

  # --- contatos -----------------------------------------------------------
  $auth->get('/:cod_inep/contatos' => $check)->to('gestor#contatos_index')->name('gestor_contatos_index');
  $auth->post('/:cod_inep/contatos' => $check)->to('gestor#contatos_create')->name('gestor_contatos_create');
  # import ANTES de /:id para ganhar na especificidade.
  $auth->post('/:cod_inep/contatos/import' => $check)->to('gestor#contatos_import')->name('gestor_contatos_import');
  $auth->put('/:cod_inep/contatos/:id' => $check)->to('gestor#contatos_update')->name('gestor_contatos_update');
  $auth->delete('/:cod_inep/contatos/:id' => $check)->to('gestor#contatos_destroy')->name('gestor_contatos_destroy');

  # --- grupos (drag-and-drop no painel de contatos) -----------------------
  $auth->get('/:cod_inep/grupos' => $check)->to('gestor#grupos_index')->name('gestor_grupos_index');
  $auth->post('/:cod_inep/grupos' => $check)->to('gestor#grupos_create')->name('gestor_grupos_create');
  $auth->put('/:cod_inep/grupos/:id' => $check)->to('gestor#grupos_update')->name('gestor_grupos_update');
  $auth->delete('/:cod_inep/grupos/:id' => $check)->to('gestor#grupos_destroy')->name('gestor_grupos_destroy');

  # --- reuniões -----------------------------------------------------------
  $auth->get('/:cod_inep' => $check)->to('gestor#escola_perfil')->name('gestor_escola_perfil');
  $auth->post('/:cod_inep/transferencia' => $check)->to('gestor#agenda_transferir')->name('gestor_agenda_transferir');
  $auth->get('/:cod_inep/reunioes' => $check)->to('gestor#reunioes_index')->name('gestor_reunioes_index');
  $auth->post('/:cod_inep/reunioes' => $check)->to('gestor#reunioes_create')->name('gestor_reunioes_create');
  $auth->get('/:cod_inep/reunioes/:id' => $check)->to('gestor#reunioes_show')->name('gestor_reunioes_show');
  $auth->put('/:cod_inep/reunioes/:id' => $check)->to('gestor#reunioes_update')->name('gestor_reunioes_update');
  $auth->delete('/:cod_inep/reunioes/:id' => $check)->to('gestor#reunioes_destroy')->name('gestor_reunioes_destroy');
  $auth->post('/:cod_inep/reunioes/:id/ata' => $check)->to('gestor#reunioes_salvar_ata')->name('gestor_reunioes_ata');
  $auth->post('/:cod_inep/reunioes/:id/marcar-realizada' => $check)->to('gestor#reunioes_marcar_realizada')->name('gestor_reunioes_marcar_realizada');
  $auth->post('/:cod_inep/reunioes/:id/cancelar' => $check)->to('gestor#reunioes_cancelar')->name('gestor_reunioes_cancelar');
  # anexos (multipart) e download — registro da reunião protegido por cod_inep.
  $auth->post('/:cod_inep/reunioes/:id/anexos/:tipo' => [ @$check, @$tipo ])
    ->to('gestor#reunioes_anexos')->name('gestor_reunioes_anexos');
  $auth->get('/:cod_inep/reunioes/:id/anexos/:tipo' => [ @$check, @$tipo ])
    ->to('gestor#reunioes_anexo_get')->name('gestor_reunioes_anexo_get');
}

1;
