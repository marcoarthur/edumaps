package EduMaps::Task::CanaisRetencao;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# ============================================================================
# RETENÇÃO DOS DADOS DAS LISTAS COM QR (issue #214, Fase 2 — RF-207)
# ============================================================================
#
# Task Minion `canais_retencao` (mesmo padrão da `telegram_polling`):
#
#   - DIÁRIA e autorreagendável: cada job executa as três regras
#     (Canal::Exclusao::retencao_executar) e enfileira o próximo com delay de
#     24h. Config desligada (canais.retencao.enabled = false) → o job PARA
#     sem reagendar;
#   - lock Minion `canais_retencao` — uma execução por vez. Job diário sem o
#     lock (há uma execução avulsa em curso) reagenda-se para daqui a
#     $DELAY_LOCK, para não perder a cadeia;
#   - `{manual => 1}`: execução avulsa (admin, "Executar agora"), uma vez, SEM
#     reagendar; roda mesmo com a config desligada (ação explícita do admin);
#   - início: boot do worker Minion se enabled (evento `wait` do primeiro
#     laço — só o processo `minion worker` o emite; perform_jobs, usado em
#     teste, não), com a 1ª execução 1h depois; e helper
#     `canais_retencao_start` (imediato).
#
# `agendado` (admin) = existe job diário (não manual) pendente ou rodando.

our $TASK       = 'canais_retencao';
our $DELAY_DIA  = 86_400;
our $DELAY_LOCK = 600;
our $DELAY_ERRO = 3_600;
our $DELAY_BOOT = 3_600;   # 1ª execução após o boot do worker (não pesa no arranque)
our $LOCK_TTL   = 3_600;

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);

  # { ok => 1, job_id } | { ok => 1, ja_ativo => 1 }
  $app->helper(canais_retencao_start    => sub ($c) { iniciar($c->app) });
  $app->helper(canais_retencao_agendado => sub ($c) { agendado($c->app->minion) });
  # Execução avulsa: devolve o id do job.
  $app->helper(canais_retencao_executar => sub ($c) {
    $c->app->minion->enqueue($TASK => [{ manual => 1 }] => { attempts => 1 });
  });

  $app->minion->on(worker => sub ($minion, $worker) {
    $worker->once(wait => sub {
      my $ok = eval { _boot($app); 1 };
      $app->log->warn("canais_retencao no boot do worker falhou: $@") unless $ok;
    });
  });
}

sub _manual ($args) {
  return ref $args eq 'ARRAY' && ref $args->[0] eq 'HASH' && $args->[0]{manual} ? 1 : 0;
}

# Há job DIÁRIO (não manual) pendente (inactive) ou rodando (active)?
sub agendado ($minion) {
  my $jobs = $minion->jobs({ tasks => [$TASK], states => [qw(inactive active)] });
  while (my $j = $jobs->next) {
    return 1 unless _manual($j->{args});
  }
  return 0;
}

# Enfileira o primeiro job diário, se não houver outro. %o: delay (segundos).
sub iniciar ($app, %o) {
  return { ok => 1, ja_ativo => 1 } if agendado($app->minion);
  my $id = $app->minion->enqueue($TASK => [{}] => {
    attempts => 1, ($o{delay} ? (delay => $o{delay}) : ()) });
  return { ok => 1, job_id => $id };
}

sub _boot ($app) {
  return unless $app->model('Canal')->retencao_config->{enabled};
  my $r = iniciar($app, delay => $DELAY_BOOT);
  $app->log->info('canais_retencao iniciada no boot do worker'
    . ($r->{ja_ativo} ? ' (já agendada)' : " (job $r->{job_id})"));
}

# --- job --------------------------------------------------------------------

sub _run ($job, $estado = {}) {
  my $app    = $job->app;
  my $minion = $job->minion;
  $estado = {} unless ref $estado eq 'HASH';
  my $manual = $estado->{manual} ? 1 : 0;

  # Limpa o job anterior da cadeia (não acumular linhas).
  if (my $ant = $estado->{anterior}) {
    eval { my $j = $minion->job($ant); $j->remove if $j && $j->info->{state} eq 'finished'; };
  }

  my $model = $app->model('Canal');
  my $cfg   = $model->retencao_config;
  return $job->finish({ parado => 'desligado' }) unless $manual || $cfg->{enabled};

  my $guard = $minion->guard($TASK, $LOCK_TTL);
  unless ($guard) {
    return $job->finish({ parado => 'lock' }) if $manual;
    my $next = _reagendar($job, $DELAY_LOCK);
    return $job->finish({ adiado => 'lock', proximo => $next });
  }

  my $r = eval { $model->retencao_executar(%$cfg) };
  my $erro = $r ? undef : ($@ || 'falha desconhecida');
  undef $guard;

  if ($r) {
    $app->log->info(sprintf 'canais_retencao%s: metadados=%d pendentes=%d lista_inativa=%d',
      ($manual ? ' (manual)' : ''),
      $r->{metadados}{inscricoes} // 0, $r->{pendentes}{contatos} // 0,
      $r->{lista_inativa}{contatos} // 0);
    for my $regra (grep { $r->{$_}{erro} } keys %$r) {
      $app->log->error("canais_retencao: regra $regra: $r->{$regra}{erro}");
    }
  }
  else {
    $app->log->error("canais_retencao: $erro");
  }

  my %out = ($r ? (resultado => $r) : (erro => $erro), ($manual ? (manual => 1) : ()));
  $out{proximo} = _reagendar($job, $erro ? $DELAY_ERRO : $DELAY_DIA) unless $manual;
  return $job->finish(\%out);
}

sub _reagendar ($job, $delay) {
  return $job->minion->enqueue($TASK => [{ anterior => $job->id }]
                               => { attempts => 1, delay => $delay });
}

1;
