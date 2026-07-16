use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Utils qw(run_clustering_job cleanup_job expected_clustering_contract);
use Mojo::JSON qw(decode_json);

my $t   = Test::Mojo->new('EduMaps');
my $tag = '[task] clustering (algoritmos pesados)';

# --------------------------------------------------------------------------
# Fixture: GMM e spectral clustering sao consideravelmente mais custosos
# que kmeans/dbscan (ajuste iterativo de mistura gaussiana e decomposicao
# espectral da matriz de afinidade, respectivamente). Por isso este arquivo
# fica separado de clustering.t e usa uma cidade menor (Taubate) em vez do
# Rio de Janeiro, para manter o tempo de execucao do teste razoavel.
# --------------------------------------------------------------------------
my $table_name = 'test_cluster_heavy';
my $params     = { no_municipio => 'Taubaté' };

$t->app->schema->resultset('CensoEscolas')->search_rs($params)
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

# --------------------------------------------------------------------------
# Casos felizes: gmm e spectral, table-driven (mesmo padrao de clustering.t)
#
# clusters => 3 de proposito (nao o default de 5): com o volume menor de
# escolas de Taubate, pedir mais componentes/clusters do que o mclust
# consegue ajustar de forma estavel aumenta a chance de Mclust() retornar
# NULL por nao convergir. 3 e um valor mais seguro para um dataset pequeno.
# --------------------------------------------------------------------------
my @HAPPY_CASES = (
  {
    algorithm    => 'gmm',
    input_extra  => { clusters => 3 },
    expect_extra => { k => 3 },
  },
  {
    algorithm    => 'spectral',
    input_extra  => { clusters => 3 },
    expect_extra => { k => 3 },
  },
);

for my $case (@HAPPY_CASES) {
  my $algorithm = $case->{algorithm};

  subtest qq/
$tag <construindo um clustering com $algorithm>
  - aplicando clustering do $algorithm em uma cidade menor (Taubate)
  - teste do happy day
/ => sub {
    my $args = {
      id_column  => 'co_entidade',
      table_name => $table_name,
      schema     => 'staging',
      algorithm  => $algorithm,
      %{ $case->{input_extra} },
    };

    my $job = run_clustering_job($t, $args);

    is $job->info->{state}, 'finished', 'job finalizado com sucesso';
    like
      $job->info->{result},
      expected_clustering_contract($algorithm, $job->id, $table_name, %{ $case->{expect_extra} }),
      "Estrutura do contrato correta ($algorithm)";

    cleanup_job($t, $job);
  };
}

# --------------------------------------------------------------------------
# Validacao de argumentos especifica destes algoritmos: gmm e spectral
# reaproveitam a mesma regra de 'clusters' do kmeans (num 2..10), entao
# o mesmo limite invalido deve ser rejeitado para ambos.
# --------------------------------------------------------------------------
subtest qq/
$tag <validacao de argumentos>
  - clusters fora do intervalo permitido e rejeitado para gmm e spectral
/ => sub {
  for my $algorithm (qw/gmm spectral/) {
    my $job = run_clustering_job($t, {
      id_column  => 'co_entidade',
      table_name => $table_name,
      schema     => 'staging',
      algorithm  => $algorithm,
      clusters   => 999,
    });

    is $job->info->{state}, 'failed', "rejeitado: clusters invalido ($algorithm)";
    like $job->info->{result}, qr/Invalid arguments/,
      "mensagem de erro adequada: clusters invalido ($algorithm)";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Regressao: mesma tabela, dois algoritmos pesados diferentes - garante que
# 'algorithm' continua sendo respeitado de ponta a ponta tambem para gmm e
# spectral (nao so para kmeans/dbscan, cobertos em clustering.t).
# --------------------------------------------------------------------------
subtest qq/
$tag <regressao: algorithm precisa ser respeitado de ponta a ponta>
  - gmm e spectral chamados na mesma tabela devem produzir metadados
    de algoritmos diferentes, com centroides de formatos coerentes
    (gmm: media dos componentes gaussianos; spectral: media analoga
    por cluster, ja que spectral nao produz centroides verdadeiros)
/ => sub {
  my $gmm_job = run_clustering_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    algorithm  => 'gmm',
    clusters   => 3,
  });
  my $spectral_job = run_clustering_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    algorithm  => 'spectral',
    clusters   => 3,
  });

  my $gmm_algo      = $gmm_job->info->{result}{cluster_info}{r_meta}{algorithm};
  my $spectral_algo = $spectral_job->info->{result}{cluster_info}{r_meta}{algorithm};

  is $gmm_algo, 'gmm', 'job de gmm reporta algorithm=gmm no r_meta';
  is $spectral_algo, 'spectral', 'job de spectral reporta algorithm=spectral no r_meta';
  isnt $gmm_algo, $spectral_algo, 'algoritmos diferentes produzem r_meta.algorithm diferentes';

  cleanup_job($t, $gmm_job);
  cleanup_job($t, $spectral_job);
};

# my $ret = $t->app->schema->storage->dbh->do("DROP TABLE IF EXISTS staging.$table_name");
# ok $ret, "staging.$table_name removida do banco";

done_testing;
