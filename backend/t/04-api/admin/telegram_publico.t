# t/04-api/admin/telegram_publico.t
# Admin do bot PÚBLICO do Telegram (#212, onda 2 — contrato congelado):
#   GET    /api/admin/canais/telegram/status
#   POST   /api/admin/canais/telegram/webhook   200 · 409 · 502
#   DELETE /api/admin/canais/telegram/webhook   200 · 502
#   POST   /api/admin/canais/telegram/polling   202 · 200 (ja_ativo) · 409
# Auth 401/403. Telegram mockado (helper canais_ua → FakeUA).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $ua = FakeUA->new;
$t->app->helper(canais_ua => sub { $ua });

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('app_config.items')")
  && $dbh->selectrow_array("SELECT to_regclass('clean.canal_telegram_estado')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $model  = $t->app->model('Canal');
my $minion = $t->app->minion;
my $INEP_ADMIN = '77777771';
my $INEP_USER  = '66666661';
my $ADMIN_EMAIL = sprintf('admin.tgpub.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.tgpub.%d@edumaps.test', $$);
my $MASTER = 'chave-mestra-de-teste-12345';
my $BOT    = "EduMapsTgPub$$";
my $SENHA  = 'senha123';
my ($admin, $user);

sub limpa_jobs {
  $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = 'telegram_polling'});
}
sub limpa_config {
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.telegram.%'
             OR key LIKE 'canais.inscricao.%'});
}
END {
  return unless $has;
  limpa_config();
  limpa_jobs();
  $dbh->do('DELETE FROM clean.canal_telegram_estado WHERE bot_username = ?', {}, $BOT);
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep IN (?, ?)', {}, $INEP_ADMIN, $INEP_USER);
}

sub cfg ($k, $v) {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put("canais.$k", $v, 'teste');
}
sub liga ($modo) {
  limpa_config();
  cfg('telegram.enabled', 'true');
  cfg('telegram.token', '123456:ABCDEFGHIJ');
  cfg('telegram.bot_username', $BOT);
  cfg('telegram.recebimento', $modo);
}
sub H { return { Authorization => "Bearer $admin" } }

subtest 'setup' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, 'Escola teste bot público');
  }
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin', email => $ADMIN_EMAIL, senha => $SENHA })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Comum', email => $USER_EMAIL, senha => $SENHA })->status_is(200);
  $dbh->do(q{UPDATE clean.gestores SET access_role = 'admin' WHERE email = ?}, {}, $ADMIN_EMAIL);
  $admin = $t->post_ok('/api/gestor/login', json => { email => $ADMIN_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  $user = $t->post_ok('/api/gestor/login', json => { email => $USER_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  limpa_jobs();
  ok $admin && $user, 'tokens';
};

subtest 'auth: 401 sem token, 403 gestor comum' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  my $U = { Authorization => "Bearer $user" };
  $t->get_ok('/api/admin/canais/telegram/status')->status_is(401);
  $t->post_ok('/api/admin/canais/telegram/webhook')->status_is(401);
  $t->delete_ok('/api/admin/canais/telegram/webhook')->status_is(401);
  $t->post_ok('/api/admin/canais/telegram/polling')->status_is(401);
  $t->get_ok('/api/admin/canais/telegram/status', $U)->status_is(403);
  $t->post_ok('/api/admin/canais/telegram/webhook', $U)->status_is(403);
  $t->delete_ok('/api/admin/canais/telegram/webhook', $U)->status_is(403);
  $t->post_ok('/api/admin/canais/telegram/polling', $U)->status_is(403);
  is scalar(@{ $ua->calls }), 0, 'nenhuma chamada ao Telegram';
};

subtest 'webhook: 409, set 200 (payload), status, 502, delete' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;

  liga('polling');
  $t->post_ok('/api/admin/canais/telegram/webhook', H())->status_is(409, 'modo polling');
  liga('webhook');
  $t->post_ok('/api/admin/canais/telegram/webhook', H())->status_is(409, 'sem segredo');
  cfg('telegram.webhook_secret', 'segredo-do-webhook-123');
  $t->post_ok('/api/admin/canais/telegram/webhook', H())->status_is(409, 'sem public_base_url');
  cfg('inscricao.public_base_url', 'https://edumaps.exemplo.org/');
  is scalar(@{ $ua->calls }), 0, 'nada chamado nos 409';

  $ua->clear;
  $t->post_ok('/api/admin/canais/telegram/webhook', H())->status_is(200)
    ->json_is('/ok', 1)->json_is('/url', 'https://edumaps.exemplo.org/api/canais/telegram/webhook');
  my $c = $ua->last_call;
  is $c->{method}, 'setWebhook', 'setWebhook';
  like $c->{url}, qr{/bot123456:ABCDEFGHIJ/setWebhook$}, 'token do bot público';
  is $c->{json}, { url => 'https://edumaps.exemplo.org/api/canais/telegram/webhook',
    secret_token => 'segredo-do-webhook-123', allowed_updates => ['message'] }, 'payload';

  $ua->responder(sub ($url, $json, $call) {
    return (200, { ok => true, result => { url => 'https://edumaps.exemplo.org/api/canais/telegram/webhook',
      pending_update_count => 2, last_error_message => 'Wrong response' } })
      if $call->{method} eq 'getWebhookInfo';
    return (200, { ok => true, result => true });
  });
  my $s = $t->get_ok('/api/admin/canais/telegram/status', H())->status_is(200)->tx->res->json;
  is $s->{enabled}, 1, 'enabled';
  is $s->{recebimento}, 'webhook', 'recebimento';
  is $s->{bot_username}, $BOT, 'bot_username';
  is $s->{webhook}{pending_update_count}, 2, 'pending_update_count';
  is $s->{webhook}{last_error_message}, 'Wrong response', 'last_error_message';
  like $s->{webhook}{url}, qr{/api/canais/telegram/webhook$}, 'url';
  is $s->{polling}, { ativo => 0, offset => 0 }, 'polling inativo';

  $ua->responder(sub { (400, { ok => false, error_code => 400, description => 'Bad Request: bad webhook' }) });
  $t->post_ok('/api/admin/canais/telegram/webhook', H())->status_is(502)
    ->json_like('/error', qr/bad webhook/);
  $t->delete_ok('/api/admin/canais/telegram/webhook', H())->status_is(502);

  $ua->responder(sub { (200, { ok => true, result => true }) });
  $ua->clear;
  $t->delete_ok('/api/admin/canais/telegram/webhook', H())->status_is(200)->json_is('/ok', 1);
  is $ua->last_call->{method}, 'deleteWebhook', 'deleteWebhook';
};

subtest 'polling: 409, 202 (deleteWebhook antes), 200 ja_ativo, status' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  limpa_jobs();

  liga('webhook');
  $t->post_ok('/api/admin/canais/telegram/polling', H())->status_is(409, 'modo webhook');
  liga('polling');
  cfg('telegram.enabled', 'false');
  $t->post_ok('/api/admin/canais/telegram/polling', H())->status_is(409, 'bot desligado');
  liga('polling');

  $ua->clear;
  my $r = $t->post_ok('/api/admin/canais/telegram/polling', H())->status_is(202)
    ->json_is('/ok', 1)->tx->res->json;
  ok $r->{job_id}, 'job_id';
  is $ua->calls_to('deleteWebhook')->@*, 1, 'deleteWebhook antes de iniciar';
  is $minion->job($r->{job_id})->task, 'telegram_polling', 'job telegram_polling';

  $t->post_ok('/api/admin/canais/telegram/polling', H())->status_is(200)
    ->json_is('/ok', 1)->json_is('/ja_ativo', 1);

  $model->salvar_telegram_offset($BOT, 42);
  my $s = $t->get_ok('/api/admin/canais/telegram/status', H())->status_is(200)->tx->res->json;
  is $s->{polling}, { ativo => 1, offset => 42 }, 'polling ativo com offset';
  ok !exists $s->{webhook}, 'sem bloco webhook no modo polling';
  limpa_jobs();
};

done_testing;
