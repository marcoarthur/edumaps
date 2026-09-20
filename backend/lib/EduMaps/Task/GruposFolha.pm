package EduMaps::Task::GruposFolha;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Syntax::Keyword::Try;
use utf8;

# Backfill dos grupos pré-listados a partir da folha de pagamento:
#   seed_grupos_folha => [$cod_inep]   (job)
#   app->seed_grupos_folha_escola(...) (helper que enfileira)
# A sincronização é por escola e idempotente (UNIQUE cod_inep, nome).

sub register ($self, $app, @args) {
  $app->minion->add_task(seed_grupos_folha => \&_seed);
  $app->helper(seed_grupos_folha_escola => \&_enqueue);
}

sub _seed ($job, $cod_inep) {
  my $model = $job->app->model('Gestor');
  my $criados = eval { $model->sincronizar_grupos_folha($cod_inep + 0) };

  if ($@) {
    $job->app->log->error("seed grupos folha de $cod_inep falhou: $@");
    return $job->fail($@);
  }

  return $job->finish({ cod_inep => $cod_inep + 0, criados => $criados });
}

sub _enqueue ($app, $cod_inep) {
  return $app->minion->enqueue(seed_grupos_folha => [$cod_inep + 0] => { attempts => 3 });
}

1;