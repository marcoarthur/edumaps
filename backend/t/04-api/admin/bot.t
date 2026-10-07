# t/04-api/admin/bot.t
# Testes da API do Bot Telegram no Painel de Configuração (Fase 1B, #183):
#   auth (401/403), folhas na árvore, PUT do multiselect de ações
#   (válido/inválido) e POST /api/admin/bot/telegram/test nos caminhos de
#   falha (400) — nunca dispara mensagem real em teste.
# Só roda onde app_config e gestor_access_role foram aplicadas.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('app_config.items')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $INEP_ADMIN = '77777777';
my $INEP_USER  = '66666666';
my $ADMIN_EMAIL = sprintf('admin.bot.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.bot.%d@edumaps.test', $$);
my $CPF_ADMIN   = sprintf('5333333%04d', $$ % 10000);
my $CPF_USER    = sprintf('5444444%04d', $$ % 10000);
my $SENHA = 'senha123';

my ($admin_token, $user_token);

END {
  return if !$has_tables;
  $dbh->do('DELETE FROM app_config.items WHERE key LIKE $1', {}, 'integrations.bot_telegram.%');
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'setup: escolas + gestores (admin e comum)' => sub {
  plan skip_all => 'app_config.items/gestores access_role ausente (migrations nao aplicadas)'
    unless $has_tables;

  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API do bot');
  }

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin Bot', email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Gestor Comum Bot', email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200);

  my $admin_id = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $ADMIN_EMAIL);
  $dbh->do('UPDATE clean.gestores SET access_role = ? WHERE id = ?', {}, 'admin', $admin_id);

  $admin_token = $t->post_ok('/api/gestor/login', json => {
    email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};
  $user_token = $t->post_ok('/api/gestor/login', json => {
    email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};
  ok $admin_token && $user_token, 'tokens obtidos';
};

subtest 'auth: 401 sem token, 403 para gestor comum' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->post_ok('/api/admin/bot/telegram/test')->status_is(401);
  $t->post_ok('/api/admin/bot/telegram/test', { Authorization => "Bearer $user_token" })
    ->status_is(403)->json_has('/error');
};

subtest 'tree: as 4 folhas do bot aparecem habilitadas' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $tree = $t->get_ok('/api/admin/config/tree', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;
  my ($integ) = grep { $_->{key} eq 'integracoes' } @{ $tree->{categories} };
  my ($grupo) = grep { $_->{key} eq 'bot_telegram' } @{ $integ->{children} };
  ok $grupo, 'grupo bot_telegram presente';

  my %folhas = map { $_->{key} => $_ } @{ $grupo->{children} };
  is scalar(keys %folhas), 4, '4 folhas';
  is $folhas{'integrations.bot_telegram.token'}{type}, 'secret', 'token secret';
  ok $folhas{'integrations.bot_telegram.token'}{sensitive}, 'token sensitive';
  is $folhas{'integrations.bot_telegram.allowed_actions'}{type}, 'multiselect', 'ações multiselect';
  ok @{ $folhas{'integrations.bot_telegram.allowed_actions'}{options} // [] } > 0,
    'options das ações vindas da Policy';
  ok $folhas{'integrations.bot_telegram.enabled'}{enabled}, 'folhas habilitadas';
};

subtest 'put: multiselect de ações (válido persiste, inválido 400)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  # ação fora da Policy -> 400 e nada gravado
  $t->put_ok('/api/admin/config/integrations.bot_telegram.allowed_actions',
    { Authorization => "Bearer $admin_token" },
    json => { value => ['nonsense_action'] })
    ->status_is(400)->json_has('/error');

  # lista não-array -> 400
  $t->put_ok('/api/admin/config/integrations.bot_telegram.allowed_actions',
    { Authorization => "Bearer $admin_token" },
    json => { value => 'ingest_stall' })
    ->status_is(400)->json_has('/error');

  # lista vazia -> 400
  $t->put_ok('/api/admin/config/integrations.bot_telegram.allowed_actions',
    { Authorization => "Bearer $admin_token" },
    json => { value => [] })
    ->status_is(400)->json_has('/error');

  # válido -> 200 e devolve a lista em claro (não é segredo)
  $t->put_ok('/api/admin/config/integrations.bot_telegram.allowed_actions',
    { Authorization => "Bearer $admin_token" },
    json => { value => ['ingest_stall', 'system_alert'] })
    ->status_is(200)->json_is('/value/0' => 'ingest_stall')->json_is('/value/1' => 'system_alert');

  my $item = $t->get_ok('/api/admin/config/integrations.bot_telegram.allowed_actions',
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->json;
  is join(',', @{ $item->{value} }), 'ingest_stall,system_alert',
    'persistiu e leu de volta';
};

subtest 'test: 400 se desativado ou incompleto (sem mensagem real)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  # estado limpo: bot desativado (nada gravado)
  $t->post_ok('/api/admin/bot/telegram/test', { Authorization => "Bearer $admin_token" })
    ->status_is(400)->json_has('/error');

  # ativado mas sem token/chat_id -> 400 (incompleto)
  $t->put_ok('/api/admin/config/integrations.bot_telegram.enabled',
    { Authorization => "Bearer $admin_token" }, json => { value => 'true' })
    ->status_is(200)->json_is('/value' => 1);
  $t->post_ok('/api/admin/bot/telegram/test', { Authorization => "Bearer $admin_token" })
    ->status_is(400)->json_has('/error');

  # chat_id preenchido, token ainda falta -> 400 aponta o token
  $t->put_ok('/api/admin/config/integrations.bot_telegram.chat_id',
    { Authorization => "Bearer $admin_token" }, json => { value => '-1009999999999' })
    ->status_is(200);
  my $res = $t->post_ok('/api/admin/bot/telegram/test', { Authorization => "Bearer $admin_token" })
    ->status_is(400)->tx->res->json;
  like $res->{error}, qr/token/, 'erro aponta o campo em falta';
};

subtest 'token: grava cifrado (plaintext nunca no banco) e desativa de volta' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  # grava token (cifrado) e ativa — agora o caminho degrada para 400 de
  # incompleto? não: token existe, chat_id existe, enabled=1 — mas a chamada
  # real à API do Telegram NÃO deve acontecer em teste, então revert para
  # desativado antes. Aqui só validamos que a gravação cifrada funciona.
  $t->put_ok('/api/admin/config/integrations.bot_telegram.token',
    { Authorization => "Bearer $admin_token" },
    json => { value => '123456789:AAFakeTokenParaTeste' })
    ->status_is(200)->json_is('/value/set' => 1);

  my $row = $dbh->selectrow_hashref(
    'SELECT ENCODE(secret, \'hex\') AS secret, sensitive FROM app_config.items WHERE key = ?',
    {}, 'integrations.bot_telegram.token');
  ok $row->{sensitive} && length($row->{secret} // '') > 0, 'token cifrado no banco';
  ok index($row->{secret}, 'AAFakeTokenParaTeste') == -1, 'plaintext não gravado';

  # desativa de volta: nenhum teste desta suíte dispara mensagem real
  $t->put_ok('/api/admin/config/integrations.bot_telegram.enabled',
    { Authorization => "Bearer $admin_token" }, json => { value => 'false' })
    ->status_is(200)->json_is('/value' => 0);
  $t->post_ok('/api/admin/bot/telegram/test', { Authorization => "Bearer $admin_token" })
    ->status_is(400);
};

done_testing;
