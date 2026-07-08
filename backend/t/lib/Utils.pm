package Utils;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Test2::V1 -ipP;
use Test2::Tools::Compare qw(D);
use Exporter 'import';

our @EXPORT_OK = qw(
  filter_resultsets c random_schools_ids random_schools_with_grades random_city_id
  run_clustering_job cleanup_job expected_clustering_contract
);
our $sch = EduMaps::Schema->go;

sub filter_resultsets($filter_cb) {
  c($sch->sources)->map( sub { $sch->resultset($_ ) } )->grep( $filter_cb );
}
sub random_schools_ids ($size = 10){
  $sch->resultset('CensoEscolas')
  ->columns(['co_entidade'])->random_sample($size)->get_all;
}
sub random_schools_with_grades ($size = 10){
  $sch->resultset('IdebNotasEscolas')->columns(['id_escola'])
  ->random_sample($size)->get_all;
}
sub random_city_id ($size = 10) {
  $sch->resultset('MunicipiosSp')->random_sample($size)
  ->columns(['codigo_ibge', 'nome_municipio'])
  ->get_all;
}

# --------------------------------------------------------------------------
# Helpers de teste para EduMaps::Task::Clustering
#
# Compartilhados entre t/05-tasks/clustering.t e t/05-tasks/clustering2.t
# (e qualquer outro teste futuro de clusterização), para nao duplicar o
# boilerplate enqueue -> perform_jobs -> job() nem a estrutura do contrato
# esperado em cada arquivo.
# --------------------------------------------------------------------------

# Enfileira, executa e retorna o job ja finalizado.
#
# @param $t    Test::Mojo instance
# @param $args hashref de argumentos para apply_clustering
sub run_clustering_job ($t, $args) {
  my $id  = $t->app->apply_clustering($args);
  my $job = $t->app->minion->job($id);
  $t->app->minion->perform_jobs;
  return $job;
}

# Remove o job do backend do Minion, com a asserção de limpeza embutida.
#
# @param $t   Test::Mojo instance
# @param $job Minion::Job ja finalizado/falho
sub cleanup_job ($t, $job) {
  ok $t->app->minion->backend->remove_job($job->id), "job @{[ $job->id ]} removido";
}

# Monta a estrutura de contrato esperada para um job de clusterização bem
# sucedido, parametrizada pelo algoritmo, tabela alvo e parametros extras
# de entrada (ex: {k => 3} ou {eps => 1.2, min_pts => 3}).
#
# Usa D() (definido) para campos cujo valor exato varia entre execucoes
# (n_clusters, clusters) e valores literais/regex para tudo que deve ser
# fixo e previsivel - incluindo r_meta.algorithm, que precisa bater
# exatamente com o algoritmo pedido (nao apenas "existir").
#
# @param $algorithm nome do algoritmo ('kmeans', 'dbscan', 'gmm', 'spectral')
# @param $job_id    id do job no Minion
# @param $table_name nome da tabela de staging usada no teste
# @param %extra_params parametros especificos do algoritmo esperados em r_meta.params
sub expected_clustering_contract ($algorithm, $job_id, $table_name, %extra_params) {
  return {
    meta => {
      name      => "clusterization",
      job_id    => $job_id,
      algorithm => $algorithm,
      took      => qr/\d+/,
    },
    cluster_info => {
      inject_args => {
        schema_name    => 'staging',
        id_column      => 'co_entidade',
        cluster_column => 'cluster_id',
        table_name     => $table_name,
      },
      r_meta => {
        status         => 'success',
        algorithm      => $algorithm,
        run_id         => qr/^run_\d+$/,
        schema         => 'staging',
        table_name     => $table_name,
        id_column      => 'co_entidade',
        metadata_table => 'staging.clustering_metadata',
        timestamp      => qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
        n_clusters     => D(),
        clusters       => D(),
        params         => { %extra_params },
      }
    }
  };
}

1;
