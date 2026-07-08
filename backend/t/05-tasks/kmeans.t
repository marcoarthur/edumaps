use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Mojo::JSON qw(decode_json);

my $t = Test::Mojo->new('EduMaps');
my $minion = $t->app->minion;
my $table_name = 'test_cluster';
my $params = { no_municipio => 'Rio de Janeiro' };
my $rs = $t->app->schema->resultset('CensoEscolas')->search_rs($params)
->join('docente')->join('matricula')
->columns(
  [
    {escola => 'me.no_entidade'},
    {codigo => 'me.co_entidade'},
    {total_docentes_basico => 'docente.qt_doc_bas'},
    {total_docentes_medio => 'docente.qt_doc_med'},
    {matriculas_fundamental => 'matricula.qt_mat_bas'},
    {matriculas_ensino_medio => 'matricula.qt_mat_med'},
  ]
)->order_by({ -desc => 'docente.qt_doc_bas' })
->save_in_table(
  tbl_name => $table_name,
  schema => 'staging',
  temporary => 0,
);

my $tag = '[task] kmeans:';

subtest qq/
$tag <construindo um clustering>
  - aplicando clustering para resultsets
  - teste do happy day
/ => sub {
  my $args = {
    id_column => 'co_entidade',
    table_name => $table_name,
    schema => 'staging',
  };

  my $id = $t->app->apply_kmeans($args);
  my $job = $minion->job($id);
  $minion->perform_jobs;
  is $job->info->{state}, 'finished', 'job finalizado com sucesso';
  like 
    $job->info->{result},
    {
      meta => {
        name => "clusterization",
        took => qr/\d+/,
        job_id => $id
      },
      cluster_info => {
        inject_args => {
          schema_name => 'staging',
          id_column => 'co_entidade',
          cluster_column => 'cluster_id',
          table_name => $table_name,
        },
        r_meta => {
          metadata => 'kmeans_metadata',
          k_param => 5,
          status => 'success',
          run_id => qr/run_\d+/,
          centroids => L(),
        }
      }
    },
    "Estrutura do contrato correta"
  ;

  ok ($minion->backend->remove_job($id), "job $id removido");
  # my $ret = $t->app->schema->storage->dbh->do("DROP TABLE IF EXISTS staging.$table_name");
  # ok $ret, "staging.$table_name removida do banco";
};

done_testing;
