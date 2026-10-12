package EduMaps::Task::TelegramPolling;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

use EduMaps::Bots::Telegram;
use EduMaps::Channel::Telegram::Updates;

# ============================================================================
# RECEBIMENTO DO BOT PÚBLICO DO TELEGRAM — MODO POLLING (issue #212, Fase 1)
# ============================================================================
#
# Task Minion `telegram_polling` (um ciclo por job):
#
#   1. lê a config (canais.telegram.*): desligado/incompleto ou recebimento ≠
#      polling → PARA (não reagenda);
#   2. lock Minion `telegram_polling:<bot>` — garante um único job ativo; sem
#      o lock, o job termina sem reagendar (duplicata);
#   3. getUpdates(offset, timeout=25, allowed_updates=[message]);
#   4. cada update → Channel::Telegram::Updates->handle (o mesmo do webhook);
#      o `update_offset` (= update_id + 1) é persistido em
#      clean.canal_telegram_estado a cada update, ANTES de reagendar — sem
#      perda nem reprocessamento ao reiniciar;
#   5. solta o lock e reagenda a si mesma (delay de 1s; em erro, backoff
#      5s, 10s, 20s... até 5 min). Os updates que chegam no intervalo esperam
#      no Telegram e saem no próximo getUpdates.
#
# Telegram recusa getUpdates com webhook ativo (409): o ciclo chama
# deleteWebhook e tenta de novo no próximo job.
#
# Início: endpoint admin (POST /api/admin/canais/telegram/polling, helper
# `telegram_polling_start`) e o boot do worker Minion se a config pedir
# polling (evento `wait` do primeiro laço do worker — só o processo
# `minion worker` o emite; perform_jobs, usado em teste, não).

our $TASK         = 'telegram_polling';
our $LONG_TIMEOUT = 25;    # segundos do long polling (getUpdates)
our $DELAY_OK     = 1;     # reagendamento normal
our $DELAY_MAX    = 300;   # teto do backoff em erro
our $LOCK_TTL     = $LONG_TIMEOUT + 60;

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);

  # Inicia o polling se não houver job ativo/pendente.
  # { ok => 1, job_id } | { ok => 1, ja_ativo => 1 }
  $app->helper(telegram_polling_start => sub ($c, %o) { iniciar($c->app, %o) });
  $app->helper(telegram_polling_ativo => sub ($c) { ativo($c->app->minion) });

  # Boot do worker: só no laço real (`minion worker`), uma vez por processo.
  $app->minion->on(worker => sub ($minion, $worker) {
    $worker->once(wait => sub {
      my $ok = eval { _boot($app); 1 };
      $app->log->warn("telegram_polling no boot do worker falhou: $@") unless $ok;
    });
  });
}

# Há job telegram_polling pendente (inactive) ou rodando (active)?
sub ativo ($minion) {
  my $jobs = $minion->jobs({ tasks => [$TASK], states => [qw(inactive active)] });
  return $jobs->total ? 1 : 0;
}

# Enfileira o primeiro job, se não houver outro. `delete_webhook => 1` chama
# deleteWebhook antes (o Telegram recusa getUpdates com webhook ativo).
sub iniciar ($app, %o) {
  return { ok => 1, ja_ativo => 1 } if ativo($app->minion);
  if ($o{delete_webhook}) {
    my $cfg = $o{config} // $app->model('Canal')->telegram_publico_config;
    my $bot = EduMaps::Bots::Telegram->new(
      config => { telegram_token => $cfg->{token} // '' },
      ua     => $app->canais_ua,
    );
    my $r = $bot->api_call(deleteWebhook => {});
    $app->log->warn("telegram_polling: deleteWebhook falhou: " . ($r->{error} // '?'))
      unless $r->{ok};
  }
  my $id = $app->minion->enqueue($TASK => [{}] => { attempts => 1 });
  return { ok => 1, job_id => $id };
}

sub _boot ($app) {
  my $cfg = $app->model('Canal')->telegram_publico_config;
  return unless _config_ok($cfg) && $cfg->{recebimento} eq 'polling';
  my $r = iniciar($app);
  $app->log->info('telegram_polling iniciado no boot do worker'
    . ($r->{ja_ativo} ? ' (já ativo)' : " (job $r->{job_id})"));
}

sub _config_ok ($cfg) {
  return 0 unless $cfg->{enabled};
  for (qw(token bot_username)) {
    return 0 unless defined $cfg->{$_} && length $cfg->{$_};
  }
  return 1;
}

# Atraso do próximo job após `n` erros seguidos: 5, 10, 20, ... até DELAY_MAX.
sub backoff ($n) {
  my $d = 5 * 2 ** (($n // 1) - 1);
  return $d > $DELAY_MAX ? $DELAY_MAX : $d;
}

# --- job --------------------------------------------------------------------

sub _run ($job, $estado = {}) {
  my $app    = $job->app;
  my $minion = $job->minion;
  $estado = {} unless ref $estado eq 'HASH';

  # Limpa o job anterior da cadeia (um job por ciclo → não acumular linhas).
  if (my $ant = $estado->{anterior}) {
    eval { my $j = $minion->job($ant); $j->remove if $j && $j->info->{state} eq 'finished'; };
  }

  my $model = $app->model('Canal');
  my $cfg   = $model->telegram_publico_config;
  return $job->finish({ parado => 'desligado' }) unless _config_ok($cfg);
  return $job->finish({ parado => 'recebimento' }) unless $cfg->{recebimento} eq 'polling';

  my $guard = $minion->guard("$TASK:$cfg->{bot_username}", $LOCK_TTL);
  return $job->finish({ parado => 'lock' }) unless $guard;

  my $r = eval { ciclo($app, config => $cfg, erros => $estado->{erros} // 0) };
  $r = { erro => ($@ || 'falha desconhecida'), erros => ($estado->{erros} // 0) + 1 }
    unless $r;
  undef $guard;   # solta o lock antes de reagendar

  my $delay = $r->{erro} ? backoff($r->{erros}) : ($r->{delay} // $DELAY_OK);
  my $next  = $minion->enqueue($TASK => [{
    erros    => ($r->{erro} ? $r->{erros} : 0),
    anterior => $job->id,
  }] => { attempts => 1, delay => $delay });

  $app->log->warn("telegram_polling: $r->{erro}") if $r->{erro};
  return $job->finish({ %$r, proximo => $next, delay => $delay });
}

# Um ciclo de polling (testável sem Minion). Parâmetros: config (do bot
# público), erros (seguidos até aqui), timeout (long polling).
# Devolve { processados, offset, delay } ou { erro, erros }.
sub ciclo ($app, %p) {
  my $cfg   = $p{config};
  my $model = $app->model('Canal');
  my $bot   = $cfg->{bot_username};
  my $ua    = $app->canais_ua;
  my $tg    = EduMaps::Bots::Telegram->new(
    config => { telegram_token => $cfg->{token} }, ua => $ua);

  my $offset = $model->telegram_offset($bot);
  my $res = $tg->api_call(getUpdates => {
    offset          => $offset,
    timeout         => $p{timeout} // $LONG_TIMEOUT,
    allowed_updates => ['message'],
  });

  unless ($res->{ok}) {
    my $erros = ($p{erros} // 0) + 1;
    # 409 com webhook ativo: remove o webhook; o próximo ciclo tenta de novo.
    if (($res->{status} // 0) == 409 && ($res->{error} // '') =~ /webhook/i) {
      my $d = $tg->api_call(deleteWebhook => {});
      return { erro => "getUpdates recusado (webhook ativo); deleteWebhook "
                       . ($d->{ok} ? 'ok' : 'falhou'), erros => $erros };
    }
    return { erro => 'getUpdates: ' . ($res->{error} // 'falha'), erros => $erros };
  }

  my $handler = EduMaps::Channel::Telegram::Updates->new(
    model => $model, config => $cfg, log => $app->log, ua => $ua);

  my $n = 0;
  my @updates = sort { ($a->{update_id} // 0) <=> ($b->{update_id} // 0) }
                grep { ref $_ eq 'HASH' && defined $_->{update_id} }
                @{ ref $res->{result} eq 'ARRAY' ? $res->{result} : [] };
  for my $u (@updates) {
    my $ok = eval { $handler->handle($u); 1 };
    $app->log->error("telegram_polling: update $u->{update_id}: $@") unless $ok;
    # avança mesmo em erro: um update defeituoso não pode travar a fila
    $offset = $model->salvar_telegram_offset($bot, $u->{update_id} + 1);
    $n++;
  }

  return { processados => $n, offset => $offset, delay => $DELAY_OK };
}

1;
