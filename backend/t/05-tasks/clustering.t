use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Utils qw(run_clustering_job cleanup_job expected_clustering_contract);
use Mojo::JSON qw(decode_json);

my $t   = Test::Mojo->new('EduMaps');
my $tag = '[task] clustering';

# --------------------------------------------------------------------------
# Fixture: uma unica tabela de staging reaproveitada por todos os subtestes.
# Evita recriar a tabela (e reprocessar o join pesado) a cada algoritmo.
# --------------------------------------------------------------------------
my $table_name = 'test_cluster';
my $params     = { no_municipio => 'Rio de Janeiro' };

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
# Casos felizes, table-driven: um por algoritmo com script R implementado.
# Adicionar um novo algoritmo aqui garante cobertura automatica assim que
# o script R correspondente existir, sem duplicar subtests inteiros.
# --------------------------------------------------------------------------
my @HAPPY_CASES = (
  {
    algorithm    => 'kmeans',
    input_extra  => { clusters => 3 },
    expect_extra => { k => 3 },
  },
  {
    algorithm    => 'dbscan',
    input_extra  => { eps => 1.5, min_pts => 3 },
    expect_extra => { eps => 1.5, min_pts => 3 },
  },
);

for my $case (@HAPPY_CASES) {
  my $algorithm = $case->{algorithm};

  subtest qq/
$tag <construindo um clustering com $algorithm>
  - aplicando clustering do $algorithm
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
# Defaults: garante que, quando os parametros especificos do algoritmo nao
# sao informados, os defaults corretos (e nao os de outro algoritmo) sao
# aplicados e efetivamente chegam ate o script R.
# --------------------------------------------------------------------------
subtest qq/
$tag <defaults por algoritmo>
  - kmeans sem 'clusters' explicito usa o default (5)
  - dbscan sem 'eps'\/'min_pts' explicitos usa os defaults (0.5 \/ 5)
/ => sub {
  for my $case (
    { algorithm => 'kmeans', expect_extra => { k => 5 } },
    { algorithm => 'dbscan', expect_extra => { eps => 0.5, min_pts => 5 } },
  ) {
    my $algorithm = $case->{algorithm};
    my $args = {
      id_column  => 'co_entidade',
      table_name => $table_name,
      schema     => 'staging',
      algorithm  => $algorithm,
    };

    my $job = run_clustering_job($t, $args);

    is $job->info->{state}, 'finished', "job de $algorithm finalizado com defaults";
    is $job->info->{result}{cluster_info}{r_meta}{params},
      $case->{expect_extra},
      "defaults de $algorithm aplicados corretamente";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Validacao de argumentos: nenhum desses deve sequer chegar a rodar R.
# --------------------------------------------------------------------------
subtest qq/
$tag <validacao de argumentos>
  - argumentos obrigatorios ausentes ou invalidos sao rejeitados
  - job falha rapido, sem tentar executar o script R
/ => sub {

  my @INVALID_CASES = (
    {
      name => 'id_column ausente',
      args => { table_name => $table_name, schema => 'staging' },
    },
    {
      name => 'table_name ausente',
      args => { id_column => 'co_entidade', schema => 'staging' },
    },
    {
      name => 'table_name com caracteres invalidos',
      args => { id_column => 'co_entidade', table_name => 'drop table; --', schema => 'staging' },
    },
    {
      name => 'algorithm fora do enum permitido',
      args => { id_column => 'co_entidade', table_name => $table_name, algorithm => 'random_forest' },
    },
    {
      name => 'clusters fora do intervalo permitido (kmeans)',
      args => { id_column => 'co_entidade', table_name => $table_name, algorithm => 'kmeans', clusters => 999 },
    },
    {
      name => 'eps negativo (dbscan)',
      args => { id_column => 'co_entidade', table_name => $table_name, algorithm => 'dbscan', eps => -1 },
    },
    {
      name => 'min_pts zero (dbscan)',
      args => { id_column => 'co_entidade', table_name => $table_name, algorithm => 'dbscan', min_pts => 0 },
    },
  );

  for my $case (@INVALID_CASES) {
    my $job = run_clustering_job($t, $case->{args});

    is $job->info->{state}, 'failed', "rejeitado: $case->{name}";
    like $job->info->{result}, qr/Invalid (arguments|algorithm)/,
      "mensagem de erro adequada: $case->{name}";

    cleanup_job($t, $job);
  }
};

# --------------------------------------------------------------------------
# Regressao especifica do bug historico: 'algorithm' precisa realmente
# direcionar qual script/funcao R roda — nao apenas ser aceito na validacao.
# Isso e coberto implicitamente pelos HAPPY_CASES acima (r_meta.algorithm
# e params conferidos por algoritmo), mas deixamos explicito aqui para que
# a intencao do teste nao se perca em uma futura refatoracao.
# --------------------------------------------------------------------------
subtest qq/
$tag <regressao: algorithm precisa ser respeitado de ponta a ponta>
  - kmeans e dbscan chamados na mesma tabela devem produzir metadados
    de algoritmos diferentes, nao o mesmo algoritmo disfarcado
/ => sub {
  my $kmeans_job = run_clustering_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    algorithm  => 'kmeans',
  });
  my $dbscan_job = run_clustering_job($t, {
    id_column  => 'co_entidade',
    table_name => $table_name,
    schema     => 'staging',
    algorithm  => 'dbscan',
  });

  my $kmeans_algo = $kmeans_job->info->{result}{cluster_info}{r_meta}{algorithm};
  my $dbscan_algo = $dbscan_job->info->{result}{cluster_info}{r_meta}{algorithm};

  is $kmeans_algo, 'kmeans', 'job de kmeans reporta algorithm=kmeans no r_meta';
  is $dbscan_algo, 'dbscan', 'job de dbscan reporta algorithm=dbscan no r_meta';
  isnt $kmeans_algo, $dbscan_algo, 'algoritmos diferentes produzem r_meta.algorithm diferentes';

  cleanup_job($t, $kmeans_job);
  cleanup_job($t, $dbscan_job);
};

done_testing;
