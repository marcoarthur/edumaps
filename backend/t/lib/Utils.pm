package Utils;
use Mojo::Base -signatures;
use Mojo::Collection qw(c);
use EduMaps::Schema;
use Test2::Tools::Basic qw(ok);
use Test2::Tools::Compare qw(D T F);
use Exporter 'import';

our @EXPORT_OK = qw(
  filter_resultsets c random_schools_ids random_schools_with_grades random_city_id
  city_id_with_grades
  run_clustering_job cleanup_job expected_clustering_contract
  run_similarity_job expected_similarity_contract
  build_r_dataframe
);
our $sch = EduMaps::Schema->go;

sub filter_resultsets($filter_cb) {
  c($sch->sources)->map( sub { $sch->resultset($_ ) } )->grep( $filter_cb );
}
sub random_schools_ids ($size = 10){
  _distintos($sch->resultset('CensoEscolas')->columns(['co_entidade']),
    'co_entidade', $size);
}
sub random_schools_with_grades ($size = 10){
  # Só escolas com linha no IDEB — é o que o `info_grades` precisa para
  # devolver algo. Sortear no Censo inteiro devolveria escolas sem nota.
  _distintos($sch->resultset('IdebNotasEscolas')->columns(['id_escola']),
    'id_escola', $size);
}
sub _distintos ($rs, $chave, $size) {
  # Um random_sample puro pode trazer a mesma escola várias vezes, e o teste
  # perde cobertura sem perceber. Amostra 3x o pedido e corta as repetidas
  # pela chave, não pelo objeto — comparar o Result direto exige has_column e
  # devolve "Not a HASH reference" no grep.
  my %visto;
  my @escolhidas = grep { !$visto{ $_->get_column($chave) }++ }
    @{ $rs->random_sample($size * 3)->get_all };
  return c(@escolhidas[0 .. $size - 1]);
}
sub random_city_id ($size = 10) {
  $sch->resultset('MunicipiosSp')->random_sample($size)
  ->columns(['codigo_ibge', 'nome_municipio'])
  ->get_all;
}
sub city_id_with_grades ($size = 10) {
  # Município com ao menos uma escola que o clustering por quantiles consegue
  # usar. Os testes que clusterizam por cidade não podem ficar a cargo da
  # sorte: nem toda cidade do banco tem escola com nota, e o contrato abaixo
  # pressupõe uma resposta com grupos.
  #
  # O predicado é clean.inep com vl_observado_2023 e vl_nota_media_2023 (os
  # filtros da consulta) — é a tabela que
  # EduMaps::Roles::Business::School::Clustering lê. Filtrar por
  # clean.ideb_notas_escolas não serve: no banco de fixtures devolve 2 cidades
  # (Ubatuba entre elas) cujo cluster sai vazio.
  #
  # O CAST acompanha o tipo real das colunas: clean.censo_escolas.co_municipio
  # é varchar e clean.municipios_sp.codigo_ibge é integer. O mesmo CAST aparece
  # na relação de CensoEscolas.
  my $sql = q{
    SELECT m.codigo_ibge
    FROM clean.municipios_sp m
    JOIN clean.censo_escolas c ON CAST(c.co_municipio AS text) = m.codigo_ibge
    JOIN clean.inep i ON i.id_escola = c.co_entidade
    -- o resultado final da consulta faz JOIN com clean.escolas
    JOIN clean.escolas e ON e.codigo_inep = c.co_entidade
    WHERE i.vl_observado_2023 IS NOT NULL
      AND i.vl_nota_media_2023 IS NOT NULL
    GROUP BY m.codigo_ibge
    -- A normalização da consulta divide por (max - min): com uma escola só, ou
    -- todas com o mesmo valor, o resultado sai vazio.
    HAVING count(DISTINCT c.co_entidade) >= 2
       AND max(i.vl_observado_2023) > min(i.vl_observado_2023)
       AND max(i.vl_nota_media_2023) > min(i.vl_nota_media_2023)
  };
  my @cidades = @{ $sch->storage->dbh->selectcol_arrayref($sql) };
  # get_all já devolve um Mojo::Collection: embrulhar em c() faria uma coleção
  # com a coleção dentro, e o chamador receberia um objeto sem codigo_ibge.
  return $sch->resultset('MunicipiosSp')->search({
    codigo_ibge => { -in => \@cidades },
  })->random_sample($size)
    ->columns(['codigo_ibge', 'nome_municipio'])->get_all;
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
  # Fila própria: sem ela o minion do Docker local pega o job antes do
  # perform_jobs e o roda no ambiente dele, não no R do host.
  my $fila = "teste_clusterization_$$";
  local $t->app->config->{minion_filas}{clusterization} = $fila;
  # Sem o cache do cliente: um resultado em cache volta sem o R regravar a
  # tabela de destino (cluster_id, pares), que o teste confere depois.
  my $client = $t->app->analytics;
  my $cache  = $client->cache_enabled;
  $client->cache_enabled(0);
  my $id  = $t->app->apply_clustering($args);
  my $job = $t->app->minion->job($id);
  $t->app->minion->perform_jobs({queues => [$fila]});
  $client->cache_enabled($cache);
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
# sucedido no motor HTTP (serviço R/Plumber, o de todos os ambientes; o
# R::Pipe legado devolve outro formato), parametrizada pelo algoritmo, tabela
# alvo e parâmetros pedidos (ex: {clusters => 3} ou {eps => 1.2, min_pts => 3}).
#
# Usa D() para campos cujo valor varia entre execuções (n_clusters, linhas) e
# valores literais/regex para o resto — incluindo metrics.algorithm e
# persisted.algorithm, que precisam bater exatamente com o algoritmo pedido.
#
# @param $algorithm nome do algoritmo ('kmeans', 'dbscan', 'gmm', 'spectral')
# @param $job_id    id do job no Minion
# @param $table_name nome da tabela de staging usada no teste
# @param %extra_params parâmetros do algoritmo esperados em r_meta.parameters
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
        analysis  => "cluster_$algorithm",
        cache_hit => F(),
        metadata  => {
          entity_id   => 'co_entidade',
          data_source => { schema => ['staging'], table_name => [$table_name] },
          features    => D(),
        },
        metrics => {
          algorithm  => $algorithm,
          n_clusters => D(),
          n_entities => D(),
        },
        parameters => { algorithm => $algorithm, %extra_params },
        persisted  => {
          algorithm      => [$algorithm],
          metadata_table => ['analytics.clustering_metadata'],
          run_id         => [qr/^run_\d+$/],
          target_table   => ["staging.$table_name"],
          rows_updated   => D(),
        },
        data   => D(),
        tables => { clusters => D() },
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
  # Fila própria: sem ela o minion do Docker local pega o job antes do
  # perform_jobs e o roda no ambiente dele, não no R do host.
  my $fila = "teste_similarity_$$";
  local $t->app->config->{minion_filas}{similarity} = $fila;
  # Sem o cache do cliente: um resultado em cache volta sem o R regravar a
  # tabela de destino (cluster_id, pares), que o teste confere depois.
  my $client = $t->app->analytics;
  my $cache  = $client->cache_enabled;
  $client->cache_enabled(0);
  my $id  = $t->app->apply_similarity($args);
  my $job = $t->app->minion->job($id);
  $t->app->minion->perform_jobs({queues => [$fila]});
  $client->cache_enabled($cache);
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
        analysis  => "${metric}_similarity",
        cache_hit => F(),
        metadata  => { entity_id => 'co_entidade', features => D() },
        metrics   => {
          n_entities      => D(),
          n_pairs         => D(),
          mean_similarity => D(),
        },
        parameters => { %extra_params },
        persisted  => {
          persisted    => [T()],
          run_id       => [qr/^run_\d+$/],
          table        => ['analytics.similarity_pairs'],
          target_table => ["staging.$table_name"],
          pairs        => D(),
        },
        data => D(),
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
