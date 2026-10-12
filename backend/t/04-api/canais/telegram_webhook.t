# t/04-api/canais/telegram_webhook.t
# Webhook do bot público do Telegram (#212, onda 2 — contrato congelado):
#   POST /api/canais/telegram/webhook  200 {ok:1} · 401 (secret) · 404 (desligado/modo)
# Fluxo completo /start → contato pelo webhook, com o Telegram mockado.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Channel::Telegram::Updates;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $ua = FakeUA->new;
$t->app->helper(canais_ua => sub { $ua });

my $dbh        = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model  = $t->app->model('Canal');
my $INEP   = 99890000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.tg.webhook.%d@edumaps.test', $$;
my $MASTER = 'chave-mestra-de-teste-12345';
my $SECRET = 'segredo-do-webhook-123';
my $CHAT   = 7500000000 + ($$ % 1000);
my $URL    = '/api/canais/telegram/webhook';
my $tk;

sub limpa {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'telegram' AND destinatario = ?},
    {}, "$CHAT");
  $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
             WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
             WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
             WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
}
sub limpa_config {
  return unless $has_config;
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.inscricao.%'
             OR key LIKE 'canais.telegram.%'});
}
END { limpa(); limpa_config(); }

sub liga_bot (%o) {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put('canais.telegram.enabled', 'true', $EMAIL);
  $model->config_put('canais.telegram.token', '123456:ABCDEFGHIJ', $EMAIL);
  $model->config_put('canais.telegram.bot_username', 'EduMapsTesteBot', $EMAIL);
  $model->config_put('canais.telegram.recebimento', $o{recebimento} // 'webhook', $EMAIL);
  $model->config_put('canais.telegram.webhook_secret', $SECRET, $EMAIL) unless $o{sem_secret};
}

my $UPD = 5000;
sub update (%m) {
  return { update_id => $UPD++, message => {
    message_id => 1, chat => { id => $CHAT, type => 'private' }, from => { id => $CHAT }, %m } };
}
sub hook ($json, $secret = $SECRET) {
  return $t->post_ok($URL, (defined $secret ? { 'X-Telegram-Bot-Api-Secret-Token' => $secret } : {}),
                     json => $json);
}

if ($has && $has_config) {
  limpa(); limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Webhook');
  my ($gid) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Webhook', $EMAIL);
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid,
                              nome => 'Exige', exige_confirmacao => 1);
  $tk = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gid)->{token};
}

subtest '404: bot desligado ou modo polling' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  limpa_config();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  hook(update(text => 'oi'))->status_is(404);
  liga_bot(recebimento => 'polling');
  hook(update(text => 'oi'))->status_is(404);
  is scalar(@{ $ua->calls }), 0, 'nada enviado';
};

subtest '401: header ausente, errado, ou segredo não configurado' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  limpa_config();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  liga_bot();
  hook(update(text => 'oi'), undef)->status_is(401);
  hook(update(text => 'oi'), 'errado')->status_is(401);
  hook(update(text => 'oi'), $SECRET . 'x')->status_is(401);
  limpa_config();
  liga_bot(sem_secret => 1);
  hook(update(text => 'oi'))->status_is(401, 'sem segredo configurado');
};

subtest '200: fluxo /start → contato → confirmado (página vê confirmado)' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  limpa_config();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put('canais.inscricao.enabled', 'true', $EMAIL);
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
  liga_bot();
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;

  my $r = $t->post_ok("/api/canais/inscricao/$tk", json => {
    nome => 'Webhook', telefone => '11955550001', consentimento => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  my $ref = $r->{confirmacao}{ref};
  is $r->{confirmacao}{canais}[0]{url}, "https://t.me/EduMapsTesteBot?start=$ref", 'deep link';

  $ua->clear;
  hook(update(text => "/start $ref"))->status_is(200)->json_is('/ok', 1);
  ok $ua->last_call->{json}{reply_markup}{keyboard}[0][0]{request_contact}, 'teclado request_contact';
  like $ua->last_call->{url}, qr{/bot123456:ABCDEFGHIJ/sendMessage$}, 'bot público';

  hook(update(contact => { phone_number => '5511955550001', user_id => $CHAT }))
    ->status_is(200)->json_is('/ok', 1);
  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(200)->json_is('/estado', 'confirmado');

  hook({ update_id => $UPD++, edited_message => { text => 'x' } })->status_is(200, 'ignorado = 200');
  $t->post_ok($URL, { 'X-Telegram-Bot-Api-Secret-Token' => $SECRET }, 'não é json')
    ->status_is(200, 'corpo inválido = 200');
};

done_testing;
