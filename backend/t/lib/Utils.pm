package Utils;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Test2::Tools::Basic qw(ok);
use Test2::Tools::Compare qw(D);
use Exporter 'import';

our @EXPORT_OK = qw(
  filter_resultsets c random_schools_ids random_schools_with_grades random_city_id
  run_clustering_job cleanup_job expected_clustering_contract
  run_similarity_job expected_similarity_contract
  build_r_dataframe
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
  ok(
    $t->app->minion->backend->remove_job($job->id),
    "job @{[ $job->id ]} removido"
  );
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

# --------------------------------------------------------------------------
# Helpers de teste para EduMaps::Task::Similarity
#
# Mesma logica dos helpers de clustering acima, adaptada ao formato de
# resultado de similarity (meta.metric em vez de meta.algorithm,
# similarity_info em vez de cluster_info, r_meta com n_entities/n_pairs/
# avg_similarity/sample_top_pairs em vez de n_clusters/clusters).
# --------------------------------------------------------------------------

# Enfileira, executa e retorna o job de similaridade ja finalizado.
#
# @param $t    Test::Mojo instance
# @param $args hashref de argumentos para apply_similarity
sub run_similarity_job ($t, $args) {
  my $id  = $t->app->apply_similarity($args);
  my $job = $t->app->minion->job($id);
  $t->app->minion->perform_jobs;
  return $job;
}

# Monta a estrutura de contrato esperada para um job de similaridade bem
# sucedido, parametrizada pela metrica, tabela de origem e parametros
# extras de entrada (ex: {composition_columns => [...]}).
#
# Assim como em expected_clustering_contract, r_meta.metric precisa bater
# exatamente com a metrica pedida - protege contra o mesmo tipo de bug de
# dispatch ja visto em Task::Clustering (metric validado mas nao usado
# para escolher a funcao/script real).
#
# @param $metric     nome da metrica ('gower', 'euclidean_zscore', ...)
# @param $job_id     id do job no Minion
# @param $table_name nome da tabela de staging usada no teste
# @param %extra_params parametros especificos da metrica esperados em r_meta.params
sub expected_similarity_contract ($metric, $job_id, $table_name, %extra_params) {
  return {
    meta => {
      name   => "similarity",
      job_id => $job_id,
      metric => $metric,
      took   => qr/\d+/,
    },
    similarity_info => {
      query_args => {
        schema_name  => 'analytics',
        output_table => 'similarity_pairs',
        target_table => "staging.$table_name",
        metric       => $metric,
      },
      r_meta => {
        status         => 'success',
        metric         => $metric,
        run_id         => qr/^run_\d+$/,
        schema         => 'staging',
        table_name     => $table_name,
        id_column      => 'co_entidade',
        output_table   => 'analytics.similarity_pairs',
        timestamp      => qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
        n_entities     => D(),
        n_pairs        => D(),
        avg_similarity => D(),
        sample_top_pairs => D(),
        params         => { %extra_params },
      }
    }
  };
}

# --------------------------------------------------------------------------
# Helper para geração de código R
#
# Transforma um hash de vetores Perl em uma definição de data.frame do R.
# Trata automaticamente valores nulos (convertendo para NA do R) e formata
# números decimais para evitar problemas de parsing no interpretador.
#
# @param $df_name Nome da variável que conterá o data.frame no R (ex: 'df')
# @param $columns_hashref Hashref de { nome_coluna => [ valores_numéricos ] }
# --------------------------------------------------------------------------
sub build_r_dataframe ($df_name, $columns_hashref) {
  my $r_df = "$df_name <- data.frame(\n";
    my @lines;

    for my $col_name (sort keys %$columns_hashref) {
      my $vec = $columns_hashref->{$col_name};

      # Converte valores numéricos formatados para string do R.
      # Undefs ou strings vazias viram "NA".
      my @formatted = map {
        (defined $_ && $_ ne '') ? sprintf("%.4f", $_) : 'NA'
      } @$vec;

      push @lines, "  $col_name = c(" . join(',', @formatted) . ")";
    }

    $r_df .= join(",\n", @lines) . "\n)\n";
  return $r_df;
}

1;
