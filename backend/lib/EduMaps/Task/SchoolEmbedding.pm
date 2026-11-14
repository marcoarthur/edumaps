package EduMaps::Task::SchoolEmbedding;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use utf8;
use DateTime;
use EduMaps::Util::MinionFila qw(minion_fila);

# ============================================================================
# EMBEDDING DAS ESCOLAS (similaridade por cosseno no pgvector) — #413
# ============================================================================
#
# analytics.school_embedding guarda, por escola, o vetor das 6 notas de
# clean.mv_escolas_scores. O painel da escola busca nele as 3 mais parecidas
# do município (ResultSet::SchoolEmbedding::similar_to).
#
# Task Minion `refresh_school_embeddings` (padrão autorreagendável da
# `planos_oficiais`, #406):
#
#   - DIÁRIA, às 05:00 de America/Sao_Paulo. Antes da #413 nada a enfileirava
#     e o embedding ficava o do backfill da migration, sem aviso, depois de um
#     Censo novo ou de um refresh das notas;
#   - insere as escolas novas, atualiza só as que mudaram e REMOVE as que
#     saíram das notas;
#   - ausência não é 0 (#154): escola com alguma nota nula fica FORA do
#     embedding (sem vizinhas, em vez de vizinhas erradas). No cosseno, um 0
#     muda a direção do vetor e aproxima a escola das que vão mal naquela nota;
#   - lock Minion — uma execução por vez;
#   - início: boot do worker Minion (evento `wait`) e helper
#     `refresh_school_embeddings_start`. O helper `refresh_school_embeddings`
#     e `{manual => 1}` rodam uma vez sem reagendar.

our $TASK       = 'refresh_school_embeddings';
our $HORA       = 5;
our $LOCK_TTL   = 1_800;
our $DELAY_LOCK = 600;
our $TZ         = 'America/Sao_Paulo';

# Ordem das dimensões do embedding — FONTE ÚNICA DE VERDADE. Precisa ser a
# mesma do backfill em data_pipeline/deploy/school_embedding.sql.
our @NOTAS = qw(
  score_capacidade_atendimento
  score_infraestrutura
  score_capacitacao_docente
  score_diversidade_discente
  score_capacidade_gestora
  score_sustentabilidade
);

sub register ($self, $app, $config = {}) {
  $app->minion->add_task($TASK => \&_run);

  $app->helper(refresh_school_embeddings => sub ($c, $args = {}) {
    $c->app->minion->enqueue($TASK => [{ manual => 1 }] => { queue => minion_fila($c->app, $TASK) });
  });
  $app->helper(refresh_school_embeddings_start => sub ($c) { iniciar($c->app) });

  $app->minion->on(worker => sub ($minion, $worker) {
    $worker->once(wait => sub {
      my $ok = eval { iniciar($app); 1 };
      $app->log->warn("$TASK no boot do worker falhou: $@") unless $ok;
    });
  });
}

# Escolas com as 6 notas presentes: só elas entram no embedding.
sub _completas ($alias = '') {
  my $p = $alias ? "$alias." : '';
  return join ' AND ', map { "$p$_ IS NOT NULL" } @NOTAS;
}

# Atualiza analytics.school_embedding a partir de $fonte (padrão: a matview
# das notas; os testes passam uma tabela temporária com as mesmas colunas).
# Não abre transação: quem chama decide (a task usa txn_do; o teste, rollback).
# Devolve { inseridas_ou_atualizadas, removidas }.
sub atualizar ($dbh, $fonte = 'clean.mv_escolas_scores') {
  die "fonte inválida: $fonte\n" unless $fonte =~ /\A[a-z_]+\.[a-z_]+\z/;
  my $completas = _completas('s');
  my $vetor     = join ', ', map {"s.$_"} @NOTAS;

  my $removidas = $dbh->do(<<~"SQL") + 0;
    DELETE FROM analytics.school_embedding e
    WHERE NOT EXISTS (
      SELECT 1 FROM $fonte s
      WHERE s.co_entidade = e.co_entidade AND $completas
    )
    SQL

  my $gravadas = $dbh->do(<<~"SQL") + 0;
    INSERT INTO analytics.school_embedding (co_entidade, embedding)
    SELECT s.co_entidade, ARRAY[$vetor]::vector
    FROM $fonte s
    WHERE $completas
    ON CONFLICT (co_entidade) DO UPDATE
      SET embedding = EXCLUDED.embedding
      WHERE analytics.school_embedding.embedding IS DISTINCT FROM EXCLUDED.embedding
    SQL

  return { inseridas_ou_atualizadas => $gravadas, removidas => $removidas };
}

# A escola tem as 6 notas? undef se nem está nas notas.
sub notas_completas ($dbh, $co_entidade) {
  my ($ok) = $dbh->selectrow_array(
    'SELECT ' . _completas() . ' FROM clean.mv_escolas_scores WHERE co_entidade = ?',
    undef, $co_entidade);
  return $ok;
}

# Segundos até as próximas 05:00 em America/Sao_Paulo.
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

  my $storage = $app->schema->storage;
  my $r = eval { $storage->txn_do(sub { atualizar($storage->dbh) }) }
    // { erro => ($@ || 'falha desconhecida') };
  undef $guard;
  if ($r->{erro}) { $app->log->error("$TASK: $r->{erro}") }
  else {
    $app->log->info(sprintf '%s: %d escola(s) inserida(s) ou atualizada(s), %d removida(s)',
      $TASK, map { $r->{$_} // 0 } qw(inseridas_ou_atualizadas removidas));
  }

  if ($manual) {
    return $r->{erro} ? $job->fail($r) : $job->finish($r);
  }
  my $next = _reagendar($job, segundos_ate_proxima());
  return $job->finish({ %$r, proximo => $next });
}

sub _reagendar ($job, $delay) {
  return $job->minion->enqueue($TASK => [{ anterior => $job->id }] => {
    attempts => 1, queue => $job->info->{queue}, delay => $delay });
}

1;
