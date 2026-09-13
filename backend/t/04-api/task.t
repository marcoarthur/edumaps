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
  $t->post_ok('/api/task/cluster' => form => {
    table_name => 'censo_escolas',
    id_column  => 'co_entidade',
    algorithm  => 'hocuspocus',
  })->status_is(400);
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