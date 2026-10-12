package EduMaps::Task::CanaisEnvio;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;

# ============================================================================
# ENVIO POR E-MAIL PARA LISTAS — JOB EM LOTES (issue #216, Fase 3)
# ============================================================================
#
# Task Minion `canais_envio [{envio_id}]` (mesmo padrão autorreagendável de
# `telegram_polling`/`canais_retencao`): um LOTE por job.
#
#   1. lock `canais_envio:<id>` (minion->guard) — um lote por envio de cada
#      vez; sem o lock, o job sai (há outro lote em curso, que reagenda);
#   2. a lógica do lote vive no model (Canal::Envios::envio_processar_lote,
#      testável sem worker): relê o envio, suspensão, config, cota diária,
#      até `ritmo_por_minuto` pendentes, contadores, conclusão;
#   3. o resultado diz se reagenda: lote seguinte em 60 s; envio desligado
#      ou SMTP indisponível em 300 s (sem mudar o estado); pausado_cota às
#      00:05 do dia seguinte (America/Sao_Paulo); agendado ainda no futuro
#      no tempo que falta. Cancelado/concluído/rascunho/suspenso → sai;
#   4. o próximo job leva `anterior` (o job finalizado é removido, para não
#      acumular linhas) e o `minion_job_id` do envio é atualizado.
#
# Erro inesperado no lote: registra e reagenda em 300 s (o estado vive no
# banco; só `pendente` é processado — reprocessar nunca reenvia).
#
# O disparo (API) enfileira pelo helper `canais_envio_enfileirar` com `delay`
# = agendado_para - agora (ou 0). O transporte SMTP vem do helper
# `canais_smtp` (injetável em teste); o token de saída usa o segredo do app.

our $TASK        = 'canais_envio';
our $LOCK_TTL    = 900;
our $DELAY_ERRO  = 300;

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);

  # Enfileira um lote do envio. Devolve o id do job.
  $app->helper(canais_envio_enfileirar => sub ($c, $envio_id, $delay = 0, %o) {
    enfileirar($c->app, $envio_id, $delay, %o);
  });
}

sub enfileirar ($app, $envio_id, $delay = 0, %o) {
  my $id = $app->minion->enqueue($TASK => [{
    envio_id => $envio_id + 0,
    ($o{anterior} ? (anterior => $o{anterior}) : ()),
  }] => { attempts => 1, ($delay && $delay > 0 ? (delay => $delay) : ()) });
  return $id;
}

# --- job --------------------------------------------------------------------

sub _run ($job, $estado = {}) {
  my $app    = $job->app;
  my $minion = $job->minion;
  $estado = {} unless ref $estado eq 'HASH';
  my $envio_id = $estado->{envio_id};
  return $job->finish({ parado => 'sem_envio' })
    unless defined $envio_id && $envio_id =~ /^\d+\z/;

  # Limpa o job anterior da cadeia (não acumular linhas).
  if (my $ant = $estado->{anterior}) {
    eval { my $j = $minion->job($ant); $j->remove if $j && $j->info->{state} eq 'finished'; };
  }

  my $guard = $minion->guard("$TASK:$envio_id", $LOCK_TTL);
  return $job->finish({ parado => 'lock' }) unless $guard;

  my $model = $app->model('Canal');
  my $r = eval {
    $model->envio_processar_lote($envio_id,
      secret         => $app->secrets->[0],
      smtp_transport => $app->build_controller->canais_smtp,
      log            => $app->log,
    );
  };
  unless ($r) {
    my $erro = $@ || 'falha desconhecida';
    $app->log->error("canais_envio $envio_id: $erro");
    $r = { reagendar => $DELAY_ERRO, erro => "$erro" };
  }
  undef $guard;   # solta o lock antes de reagendar

  if (defined $r->{reagendar}) {
    my $next = enfileirar($app, $envio_id, $r->{reagendar}, anterior => $job->id);
    eval {
      $model->_rows('UPDATE clean.canal_envios SET minion_job_id = ? WHERE id = ?',
                    $next + 0, $envio_id + 0);
    };
    return $job->finish({ %$r, proximo => $next });
  }
  return $job->finish($r);
}

1;
