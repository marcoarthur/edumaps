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

  # --- inventário escolar (recursos e serviços) ---------------------------
  my $id_check    = [ @$check, @$rid ];
  my $anexo_check = [ @$check, anexo_id => qr/\d+/ ];

  $auth->get('/:cod_inep/inventario' => $check)->to('gestor#inventario_index')->name('gestor_inventario');
  $auth->post('/:cod_inep/inventario/importar-censo' => $check)
    ->to('gestor#inventario_importar_censo')->name('gestor_inventario_importar_censo');

  $auth->post('/:cod_inep/inventario/categorias' => $check)
    ->to('gestor#inventario_categoria_create')->name('gestor_inventario_categoria_create');
  $auth->put('/:cod_inep/inventario/categorias/:id' => $id_check)
    ->to('gestor#inventario_categoria_update')->name('gestor_inventario_categoria_update');
  $auth->delete('/:cod_inep/inventario/categorias/:id' => $id_check)
    ->to('gestor#inventario_categoria_destroy')->name('gestor_inventario_categoria_destroy');

  $auth->post('/:cod_inep/inventario/fornecedores' => $check)
    ->to('gestor#inventario_fornecedor_create')->name('gestor_inventario_fornecedor_create');
  $auth->put('/:cod_inep/inventario/fornecedores/:id' => $id_check)
    ->to('gestor#inventario_fornecedor_update')->name('gestor_inventario_fornecedor_update');
  $auth->delete('/:cod_inep/inventario/fornecedores/:id' => $id_check)
    ->to('gestor#inventario_fornecedor_destroy')->name('gestor_inventario_fornecedor_destroy');

  $auth->get('/:cod_inep/inventario/itens' => $check)
    ->to('gestor#inventario_itens_index')->name('gestor_inventario_itens');
  $auth->post('/:cod_inep/inventario/itens' => $check)
    ->to('gestor#inventario_item_create')->name('gestor_inventario_item_create');
  $auth->get('/:cod_inep/inventario/itens/:id' => $id_check)
    ->to('gestor#inventario_item_show')->name('gestor_inventario_item');
  $auth->put('/:cod_inep/inventario/itens/:id' => $id_check)
    ->to('gestor#inventario_item_update')->name('gestor_inventario_item_update');
  $auth->delete('/:cod_inep/inventario/itens/:id' => $id_check)
    ->to('gestor#inventario_item_destroy')->name('gestor_inventario_item_destroy');

  $auth->post('/:cod_inep/inventario/itens/:id/anexos' => $id_check)
    ->to('gestor#inventario_anexo_create')->name('gestor_inventario_anexo_create');
  $auth->get('/:cod_inep/inventario/itens/:id/anexos/:anexo_id' => $anexo_check)
    ->to('gestor#inventario_anexo_get')->name('gestor_inventario_anexo_get');
  $auth->delete('/:cod_inep/inventario/itens/:id/anexos/:anexo_id' => $anexo_check)
    ->to('gestor#inventario_anexo_delete')->name('gestor_inventario_anexo_delete');

  # --- relações institucionais (entidades externas + relações) ------------
  $auth->get('/:cod_inep/relacoes' => $check)->to('gestor#relacoes_index')->name('gestor_relacoes');

  $auth->post('/:cod_inep/relacoes/categorias' => $check)
    ->to('gestor#relacoes_categoria_create')->name('gestor_relacoes_categoria_create');
  $auth->put('/:cod_inep/relacoes/categorias/:id' => $id_check)
    ->to('gestor#relacoes_categoria_update')->name('gestor_relacoes_categoria_update');
  $auth->delete('/:cod_inep/relacoes/categorias/:id' => $id_check)
    ->to('gestor#relacoes_categoria_destroy')->name('gestor_relacoes_categoria_destroy');

  $auth->get('/:cod_inep/relacoes/entidades' => $check)
    ->to('gestor#relacoes_entidade_index')->name('gestor_relacoes_entidades');
  $auth->post('/:cod_inep/relacoes/entidades' => $check)
    ->to('gestor#relacoes_entidade_create')->name('gestor_relacoes_entidade_create');
  $auth->get('/:cod_inep/relacoes/entidades/:id' => $id_check)
    ->to('gestor#relacoes_entidade_show')->name('gestor_relacoes_entidade');
  $auth->put('/:cod_inep/relacoes/entidades/:id' => $id_check)
    ->to('gestor#relacoes_entidade_update')->name('gestor_relacoes_entidade_update');
  $auth->delete('/:cod_inep/relacoes/entidades/:id' => $id_check)
    ->to('gestor#relacoes_entidade_destroy')->name('gestor_relacoes_entidade_destroy');

  $auth->post('/:cod_inep/relacoes' => $check)->to('gestor#relacoes_create')->name('gestor_relacoes_create');
  # agenda (visão temporal derivada) antes de /:id para ganhar na especificidade.
  $auth->get('/:cod_inep/relacoes/agenda' => $check)->to('gestor#relacoes_agenda')->name('gestor_relacoes_agenda');
  $auth->get('/:cod_inep/relacoes/:id' => $id_check)->to('gestor#relacoes_show')->name('gestor_relacoes_show');
  $auth->put('/:cod_inep/relacoes/:id' => $id_check)->to('gestor#relacoes_update')->name('gestor_relacoes_update');
  $auth->delete('/:cod_inep/relacoes/:id' => $id_check)->to('gestor#relacoes_destroy')->name('gestor_relacoes_destroy');

  # gestão da relação: interações (timeline) e documentos (anexos).
  my $inter_check = [ @$check, id => qr/\d+/, interacao_id => qr/\d+/ ];
  my $doc_check   = [ @$check, id => qr/\d+/, documento_id => qr/\d+/ ];

  $auth->post('/:cod_inep/relacoes/:id/interacoes' => $id_check)
    ->to('gestor#relacoes_interacao_create')->name('gestor_relacoes_interacao_create');
  $auth->put('/:cod_inep/relacoes/:id/interacoes/:interacao_id' => $inter_check)
    ->to('gestor#relacoes_interacao_update')->name('gestor_relacoes_interacao_update');
  $auth->delete('/:cod_inep/relacoes/:id/interacoes/:interacao_id' => $inter_check)
    ->to('gestor#relacoes_interacao_destroy')->name('gestor_relacoes_interacao_destroy');

  $auth->post('/:cod_inep/relacoes/:id/documentos' => $id_check)
    ->to('gestor#relacoes_documento_create')->name('gestor_relacoes_documento_create');
  $auth->get('/:cod_inep/relacoes/:id/documentos/:documento_id' => $doc_check)
    ->to('gestor#relacoes_documento_get')->name('gestor_relacoes_documento_get');
  $auth->delete('/:cod_inep/relacoes/:id/documentos/:documento_id' => $doc_check)
    ->to('gestor#relacoes_documento_delete')->name('gestor_relacoes_documento_delete');
}

1;
