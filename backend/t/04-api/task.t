use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';
use utf8;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

# ------------------------------------------------------------
# POST /api/task/cluster
# ------------------------------------------------------------
subtest 'request_cluster: enfileira e retorna 202 + Location' => sub {
  my $tx = $t->post_ok('/api/task/cluster' => form => {
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    algorithm  => 'kmeans',
    clusters   => 3,
  })->status_is(202)->tx;
  my $json = $tx->res->json;

  is $json->{task},   'cluster', 'task = cluster';
  ok $json->{job_id} =~ /^\d+$/, 'job_id numérico';
  like $tx->res->headers->header('Location'), qr{^/api/task/progress\?job_id=\d+$},
    'Location p/ polling';
  is $t->app->minion->job($json->{job_id})->info->{queue}, 'analytics',
    'job na fila dedicada analytics';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_cluster: sem table_name -> 400' => sub {
  $t->post_ok('/api/task/cluster' => form => {id_column => 'co_entidade'})->status_is(400);
};

subtest 'request_cluster: algoritmo inválido -> 400' => sub {
  my $tx = $t->post_ok('/api/task/cluster' => form => {
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    algorithm  => 'hocuspocus',
  })->status_is(400)->tx;
};

subtest 'request_cluster: geotag válido é convertido em filter' => sub {
  my $tx = $t->post_ok('/api/task/cluster' => form => {
    table_name    => 'censo_escolas',
    id_column     => 'co_entidade',
    codigo_regiao => '1',
    codigo_uf     => '35',
    codigo_ibge   => '3550308',
  })->status_is(202)->tx;
  my $json = $tx->res->json;
  my $args = $t->app->minion->job($json->{job_id})->args->[0];

  is $args->{filter},
    { co_regiao => 1, co_uf => 35, co_municipio => 3550308 },
    'filter montado a partir do geotag';
  is $args->{table_name}, 'censo_escolas', 'table_name preservado';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_cluster: geotag sem município gera filter parcial' => sub {
  my $tx = $t->post_ok('/api/task/cluster' => form => {
    table_name    => 'censo_escolas',
    id_column     => 'co_entidade',
    codigo_regiao => '1',
    codigo_uf     => '35',
  })->status_is(202)->tx;
  my $json = $tx->res->json;
  my $args = $t->app->minion->job($json->{job_id})->args->[0];

  is $args->{filter}, { co_regiao => 1, co_uf => 35 },
    'filter apenas com região e UF';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_cluster: geotag inválido -> 400' => sub {
  $t->post_ok('/api/task/cluster' => form => {
    table_name    => 'censo_escolas',
    id_column     => 'co_entidade',
    codigo_regiao => '9',
  })->status_is(400);

  $t->post_ok('/api/task/cluster' => form => {
    table_name    => 'censo_escolas',
    id_column     => 'co_entidade',
    codigo_ibge   => 'abc',
  })->status_is(400);
};

subtest 'request_cluster: aceita body JSON com features em array e geotag' => sub {
  my $tx = $t->post_ok('/api/task/cluster' => json => {
    table_name    => 'censo_escolas',
    id_column     => 'co_entidade',
    algorithm     => 'kmeans',
    clusters      => 3,
    features      => ['qt_salas_utilizadas', 'in_alimentacao', 'in_biblioteca'],
    codigo_regiao => 3,
    codigo_uf     => 35,
    codigo_ibge   => 3550308,
  })->status_is(202)->tx;
  my $json = $tx->res->json;
  my $args = $t->app->minion->job($json->{job_id})->args->[0];

  is $args->{features},
    ['qt_salas_utilizadas', 'in_alimentacao', 'in_biblioteca'],
    'features em array preservado';
  is $args->{filter}, { co_regiao => 3, co_uf => 35, co_municipio => 3550308 },
    'filter montado a partir do geotag JSON';
  is $args->{clusters}, 3, 'clusters numérico';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_cluster: body JSON sem chaves obrigatórias -> 400' => sub {
  $t->post_ok('/api/task/cluster' => json => {
    algorithm => 'kmeans',
  })->status_is(400);
};

# ------------------------------------------------------------
# GET /api/task/progress (resposta REST p/ polling não-SSE)
# ------------------------------------------------------------
subtest 'job_progress: REST retorna snapshot JSON do estado' => sub {
  my $job_id = $t->app->minion->enqueue(
    clusterization => [{algorithm => 'kmeans'}] => {queue => 'zzz_progress_test'}
  );

  my $tx = $t->get_ok("/api/task/progress?job_id=$job_id")->status_is(200)->tx;
  is $tx->res->json->{state}, 'inactive', 'REST retorna state em JSON para job parado';

  # Claims o job como um worker de verdade e o marca como falho; em jobs
  # `inactive` o Minion::Job->fail retorna undef (exige estado active).
  my $worker = $t->app->minion->worker;
  $worker->register;
  my $claimed = $worker->dequeue(0, {queues => ['zzz_progress_test']});
  ok $claimed, 'worker in-process dequeueou o job';
  $claimed->fail('falha simulada no R');

  my $tx2 = $t->get_ok("/api/task/progress?job_id=$job_id")->status_is(200)->tx;
  is $tx2->res->json->{state}, 'failed', 'state = failed após falha';
  like $tx2->res->json->{error}, qr/falha simulada no R/, 'erro exposto no JSON';

  $t->app->minion->backend->remove_job($job_id);
};

subtest 'job_progress: job inexistente -> 404' => sub {
  $t->get_ok('/api/task/progress?job_id=99999999')->status_is(404);
};

# ------------------------------------------------------------
# POST /api/task/summary
# ------------------------------------------------------------
subtest 'request_summary: enfileira e retorna 202 + Location' => sub {
  my $tx = $t->post_ok('/api/task/summary' => form => {
    codigo_ibge => '3550308',
    analysis    => 'full_summary',
  })->status_is(202)->tx;
  my $json = $tx->res->json;

  is $json->{task},   'summary', 'task = summary';
  ok $json->{job_id} =~ /^\d+$/, 'job_id numérico';
  like $tx->res->headers->header('Location'), qr{^/api/task/progress\?job_id=\d+$},
    'Location p/ polling';
  is $t->app->minion->job($json->{job_id})->info->{queue}, 'analytics',
    'job na fila dedicada analytics';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_summary: codigo_ibge inválido -> 400' => sub {
  $t->post_ok('/api/task/summary' => form => {codigo_ibge => 'abc'})->status_is(400);
};

# ------------------------------------------------------------
# POST /api/task/similarity
# ------------------------------------------------------------
subtest 'request_similarity: enfileira e retorna 202 + Location' => sub {
  my $tx = $t->post_ok('/api/task/similarity' => form => {
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    metric     => 'gower',
  })->status_is(202)->tx;
  my $json = $tx->res->json;

  is $json->{task},   'similarity', 'task = similarity';
  ok $json->{job_id} =~ /^\d+$/, 'job_id numérico';
  like $tx->res->headers->header('Location'), qr{^/api/task/progress\?job_id=\d+$},
    'Location p/ polling';
  is $t->app->minion->job($json->{job_id})->info->{queue}, 'analytics',
    'job na fila dedicada analytics';

  $t->app->minion->backend->remove_job($json->{job_id});
};

subtest 'request_similarity: id_column faltando -> 400' => sub {
  $t->post_ok('/api/task/similarity' => form => {table_name => 'censo_escolas'})->status_is(400);
};

done_testing;