package EduMaps::Task::PlanosOficiais;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use DateTime;
use EduMaps::Util::MinionFila qw(minion_fila);

# ============================================================================
# MEDIÇÕES OFICIAIS DOS PLANOS EM LOTE (#406, P2-RD-03)
# ============================================================================
#
# Task Minion `planos_oficiais` (mesmo padrão autorreagendável da
# `planos_alertas`):
#
#   - DIÁRIA, às 06:00 de America/Sao_Paulo (antes dos alertas das 07:00):
#     grava como medição oficial cada (ano, valor) novo das fontes nas metas
#     ligadas a indicador dos planos VIGENTES. Antes, isso só acontecia quando
#     a escola abria o plano, e o painel da rede (que só lê) ficava com o
#     número antigo;
#   - idempotente: a mesma consulta da sincronização por plano, com ON
#     CONFLICT por (meta, ano) oficial; plano encerrado continua congelado;
#   - a origem 'oficial' da medição é o registro de quem gravou: a rede
#     continua só leitura, quem grava é o job;
#   - lock Minion `planos_oficiais` — uma execução por vez;
#   - início: boot do worker Minion (evento `wait`), e helper
#     `planos_oficiais_start`. `{manual => 1}` roda uma vez sem reagendar.

our $TASK       = 'planos_oficiais';
our $HORA       = 6;
our $LOCK_TTL   = 1_800;
our $DELAY_LOCK = 600;
our $TZ         = 'America/Sao_Paulo';

sub register ($self, $app, @args) {
  $app->minion->add_task($TASK => \&_run);
  $app->helper(planos_oficiais_start => sub ($c) { iniciar($c->app) });

  $app->minion->on(worker => sub ($minion, $worker) {
    $worker->once(wait => sub {
      my $ok = eval { iniciar($app); 1 };
      $app->log->warn("planos_oficiais no boot do worker falhou: $@") unless $ok;
    });
  });
}

# Segundos até as próximas 06:00 em America/Sao_Paulo.
sub segundos_ate_proxima ($agora = undef) {
  $agora //= DateTime->now(time_zone => $TZ);
  $agora = $agora->clone->set_time_zone($TZ);
  my $alvo = $agora->clone->set(hour => $HORA, minute => 0, second => 0, nanosecond => 0);
  $alvo->add(days => 1) if $alvo <= $agora;
  return $alvo->epoch - $agora->epoch;
}

sub _agendado ($app) {
  my $jobs = $app->minion->jobs({ tasks => [$TASK], queues => [minion_fila($app, $TASK)],
                                  states => [qw(inactive active)] });
  while (my $j = $jobs->next) {
    return 1 unless ref $j->{args} eq 'ARRAY' && ref $j->{args}[0] eq 'HASH' && $j->{args}[0]{manual};
  }
  return 0;
}

sub iniciar ($app) {
  return { ok => 1, ja_ativo => 1 } if _agendado($app);
  my $id = $app->minion->enqueue($TASK => [{}] => {
    attempts => 1, queue => minion_fila($app, $TASK), delay => segundos_ate_proxima() });
  return { ok => 1, job_id => $id };
}

sub _run ($job, $estado = {}) {
  my $app    = $job->app;
  my $minion = $job->minion;
  $estado = {} unless ref $estado eq 'HASH';
  my $manual = $estado->{manual} ? 1 : 0;

  if (my $ant = $estado->{anterior}) {
    eval { my $j = $minion->job($ant); $j->remove if $j && $j->info->{state} eq 'finished'; };
  }

  my $guard = $minion->guard($TASK, $LOCK_TTL);
  unless ($guard) {
    return $job->finish({ parado => 'lock' }) if $manual;
    my $next = _reagendar($job, $DELAY_LOCK);
    return $job->finish({ adiado => 'lock', proximo => $next });
  }

  my $r = eval { $app->model('Gestor')->planos_sincronizar_oficiais } // { erro => ($@ || 'falha desconhecida') };
  undef $guard;
  if ($r->{erro}) { $app->log->error("planos_oficiais: $r->{erro}") }
  else {
    $app->log->info(sprintf 'planos_oficiais: %d medição(ões) nova(s) em %d meta(s) de %d plano(s)',
      map { $r->{$_} // 0 } qw(medicoes metas planos));
  }

  return $job->finish($r) if $manual;
  my $next = _reagendar($job, segundos_ate_proxima());
  return $job->finish({ %$r, proximo => $next });
}

sub _reagendar ($job, $delay) {
  return $job->minion->enqueue($TASK => [{ anterior => $job->id }] => {
    attempts => 1, queue => $job->info->{queue}, delay => $delay });
}

1;
