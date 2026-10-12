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

  # Bot Telegram: envio de mensagem de teste (Fase 1B — #183).
  $auth->post('/bot/telegram/test')->to('admin#bot_telegram_test')->name('admin_bot_telegram_test');

  # Bot PÚBLICO do Telegram (confirmação de posse nas listas com QR, #212):
  # status do recebimento, registro/remoção do webhook e início do polling.
  $auth->get('/canais/telegram/status')
    ->to('admin#telegram_publico_status')->name('admin_telegram_publico_status');
  $auth->post('/canais/telegram/webhook')
    ->to('admin#telegram_publico_webhook_set')->name('admin_telegram_publico_webhook_set');
  $auth->delete('/canais/telegram/webhook')
    ->to('admin#telegram_publico_webhook_delete')->name('admin_telegram_publico_webhook_delete');
  $auth->post('/canais/telegram/polling')
    ->to('admin#telegram_publico_polling')->name('admin_telegram_publico_polling');

  # Retenção (LGPD) dos dados das listas com QR (#214, RF-207): prazos,
  # última execução e execução avulsa da task `canais_retencao`.
  $auth->get('/canais/retencao')
    ->to('admin#canais_retencao_status')->name('admin_canais_retencao_status');
  $auth->post('/canais/retencao/executar')
    ->to('admin#canais_retencao_executar')->name('admin_canais_retencao_executar');

  # Consentimento versionado da autoinscrição (#214, RF-208): rascunho ->
  # publicar (vira vigente; a anterior é arquivada). Publicada é imutável.
  my $versao_id = [ id => qr/\d+/ ];
  $auth->get('/consentimento/versoes')
    ->to('admin#consentimento_versoes_index')->name('admin_consentimento_versoes_index');
  $auth->post('/consentimento/versoes')
    ->to('admin#consentimento_versoes_create')->name('admin_consentimento_versoes_create');
  $auth->put('/consentimento/versoes/:id' => $versao_id)
    ->to('admin#consentimento_versoes_update')->name('admin_consentimento_versoes_update');
  $auth->post('/consentimento/versoes/:id/publicar' => $versao_id)
    ->to('admin#consentimento_versoes_publicar')->name('admin_consentimento_versoes_publicar');

  # Telemetria de sessão: KPIs do fluxo de acesso (só agregados).
  $auth->get('/telemetry/overview')->to('admin#telemetry_overview')->name('admin_telemetry_overview');
}

1;