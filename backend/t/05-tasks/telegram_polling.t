# t/05-tasks/telegram_polling.t
# Task Minion `telegram_polling` (#212, onda 2): ciclo getUpdates → handle →
# offset persistido; reagendamento; lock (um único job); parada quando
# desligado/fora do modo; backoff em erro; 409 de webhook ativo; início no
# boot do worker. Sem serviços externos: Telegram mockado (FakeUA) e Minion
# no Postgres de teste (perform_jobs in-process).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use FakeUA;
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Task::TelegramPolling;
use EduMaps::Channel::Telegram::Updates;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $ua = FakeUA->new;
$t->app->helper(canais_ua => sub { $ua });

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_telegram_estado')")
  && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migrations nao aplicadas' unless $has;

my $app    = $t->app;
my $model  = $app->model('Canal');
my $minion = $app->minion;
my $MASTER = 'chave-mestra-de-teste-12345';
my $BOT    = "EduMapsPolling$$";
my $CHAT   = 7600000000 + ($$ % 1000);
$ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;

sub limpa_jobs { $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = 'telegram_polling'}) }
sub limpa {
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.telegram.%'});
  $dbh->do('DELETE FROM clean.canal_telegram_estado WHERE bot_username = ?', {}, $BOT);
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'telegram' AND destinatario = ?}, {}, "$CHAT");
  limpa_jobs();
  $minion->unlock("telegram_polling:$BOT");
}
END { limpa() }

sub liga (%o) {
  $model->config_put('canais.telegram.enabled', ($o{enabled} // 'true'), 't');
  $model->config_put('canais.telegram.token', '123456:ABCDEFGHIJ', 't');
  $model->config_put('canais.telegram.bot_username', $BOT, 't');
  $model->config_put('canais.telegram.recebimento', ($o{modo} // 'polling'), 't');
}

my @FILA;   # respostas do getUpdates, em ordem
$ua->responder(sub ($url, $json, $call) {
  if ($call->{method} eq 'getUpdates') {
    my $r = shift @FILA // [200, { ok => true, result => [] }];
    return @$r;
  }
  return (200, { ok => true, result => { message_id => 1 } });
});

sub upd ($id, $text) {
  return { update_id => $id, message => { message_id => $id, text => $text,
    chat => { id => $CHAT, type => 'private' }, from => { id => $CHAT } } };
}
sub jobs_ativos {
  return $minion->jobs({ tasks => ['telegram_polling'], states => [qw(inactive active)] })->total;
}
sub proximo {
  my $j = $minion->jobs({ tasks => ["telegram_polling"], states => ["inactive"] })->next;  # hashref (info)
  return $j;
}

limpa();

subtest 'ciclo: processa updates e persiste o offset' => sub {
  liga();
  EduMaps::Channel::Telegram::Updates->reset_rate_limit;
  $ua->clear;
  @FILA = ([200, { ok => true, result => [ upd(101, 'oi'), upd(100, 'ola') ] }]);
  my $cfg = $model->telegram_publico_config;
  my $r = EduMaps::Task::TelegramPolling::ciclo($app, config => $cfg);
  is $r->{processados}, 2, 'dois updates';
  is $r->{offset}, 102, 'offset = último + 1';
  is $model->telegram_offset($BOT), 102, 'offset persistido';
  my $g = $ua->calls_to('getUpdates')->[0]{json};
  is $g, { offset => 0, timeout => 25, allowed_updates => ['message'] }, 'getUpdates';
  is scalar(@{ $ua->calls_to('sendMessage') }), 2, 'respondeu os dois';

  $ua->clear;
  EduMaps::Task::TelegramPolling::ciclo($app, config => $cfg);
  is $ua->calls_to('getUpdates')->[0]{json}{offset}, 102, 'próximo ciclo usa o offset salvo';
  $model->salvar_telegram_offset($BOT, 50);
  is $model->telegram_offset($BOT), 102, 'offset nunca retrocede';
};

subtest 'job: reagenda a si mesmo (delay) e remove o anterior' => sub {
  limpa_jobs(); liga();
  @FILA = ([200, { ok => true, result => [ upd(102, 'x') ] }]);
  my $id = $minion->enqueue(telegram_polling => [{}] => { attempts => 1 });
  $minion->perform_jobs;
  my $info = $minion->job($id)->info;
  is $info->{state}, 'finished', 'finished';
  is $info->{result}{processados}, 1, 'processou';
  is $info->{result}{delay}, 1, 'delay curto';
  my $n = proximo();
  ok $n, 'próximo job enfileirado';
  is $n->{args}[0], { erros => 0, anterior => $id }, 'args do próximo';
  ok $n->{delayed} > $n->{created}, 'com delay';
  is $model->telegram_offset($BOT), 103, 'offset persistido antes de reagendar';
  ok !$minion->is_locked("telegram_polling:$BOT"), 'lock solto';

  # executa o próximo: remove o anterior (finished)
  $minion->backend->pg->db->query(q{UPDATE minion_jobs SET delayed = NOW() WHERE id = ?}, $n->{id});
  $minion->perform_jobs;
  ok !$minion->job($id), 'job anterior removido';
  is $minion->job($n->{id})->info->{state}, 'finished', 'segundo ciclo ok';
  is jobs_ativos(), 1, 'sempre um único job na cadeia';
};

subtest 'lock: duplicata termina sem reagendar' => sub {
  limpa_jobs(); liga();
  ok $minion->lock("telegram_polling:$BOT", 60), 'lock tomado por "outro" job';
  my $id = $minion->enqueue(telegram_polling => [{}] => { attempts => 1 });
  $minion->perform_jobs;
  is $minion->job($id)->info->{result}, { parado => 'lock' }, 'parado por lock';
  is jobs_ativos(), 0, 'não reagendou';
  $minion->unlock("telegram_polling:$BOT");
};

subtest 'parada: desligado ou modo webhook' => sub {
  limpa_jobs();
  liga(enabled => 'false');
  my $id = $minion->enqueue(telegram_polling => [{}] => { attempts => 1 });
  $minion->perform_jobs;
  is $minion->job($id)->info->{result}, { parado => 'desligado' }, 'desligado';
  liga(modo => 'webhook');
  $id = $minion->enqueue(telegram_polling => [{}] => { attempts => 1 });
  $minion->perform_jobs;
  is $minion->job($id)->info->{result}, { parado => 'recebimento' }, 'modo webhook';
  is jobs_ativos(), 0, 'não reagendou';
};

subtest 'erro: backoff; 409 de webhook ativo chama deleteWebhook' => sub {
  limpa_jobs(); liga();
  @FILA = ([undef]);   # falha de conexão
  my $id = $minion->enqueue(telegram_polling => [{ erros => 1 }] => { attempts => 1 });
  $minion->perform_jobs;
  my $res = $minion->job($id)->info->{result};
  like $res->{erro}, qr/getUpdates/, 'erro registrado';
  is $res->{erros}, 2, 'erros seguidos';
  is $res->{delay}, 10, 'backoff (5, 10, ...)';
  is proximo()->{args}[0]{erros}, 2, 'próximo herda o contador';
  is EduMaps::Task::TelegramPolling::backoff(20), 300, 'teto de 5 min';

  limpa_jobs();
  $ua->clear;
  @FILA = ([409, { ok => false, error_code => 409,
    description => "Conflict: can't use getUpdates method while webhook is active; use deleteWebhook to delete the webhook first" }]);
  my $r = EduMaps::Task::TelegramPolling::ciclo($app, config => $model->telegram_publico_config);
  like $r->{erro}, qr/webhook ativo/, 'erro de webhook ativo';
  is scalar(@{ $ua->calls_to('deleteWebhook') }), 1, 'deleteWebhook chamado';
};

subtest 'boot do worker: inicia se a config pede polling (uma vez)' => sub {
  limpa_jobs(); liga();
  my $w = $minion->worker;   # evento `worker` → espera o primeiro `wait`
  is jobs_ativos(), 0, 'criar o worker não enfileira';
  $w->emit('wait');
  is jobs_ativos(), 1, 'primeiro laço do worker enfileira';
  $w->emit('wait');
  is jobs_ativos(), 1, 'só uma vez';
  is $app->telegram_polling_start->{ja_ativo}, 1, 'helper: já ativo';

  limpa_jobs(); liga(modo => 'webhook');
  my $w2 = $minion->worker;
  $w2->emit('wait');
  is jobs_ativos(), 0, 'modo webhook: não inicia';
};

done_testing;
