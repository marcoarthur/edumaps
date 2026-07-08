use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use Utils qw(run_clustering_job cleanup_job);

my $t   = Test::Mojo->new('EduMaps');
my $sch = $t->app->schema;
my $tag = '[integration] inject_cluster_class_from_job';

# --------------------------------------------------------------------------
# Fixture: mesma query usada em clustering.t/sandbox, mas para Campinas -
# so para nao competir por nome de tabela com os outros arquivos de teste
# (test_cluster / test_cluster_heavy) caso rodem em paralelo.
# --------------------------------------------------------------------------
my $table_name = 'test_cluster_campinas';
my $params     = { no_municipio => 'Campinas' };

my $source_rs = $sch->resultset('CensoEscolas')->search_rs($params)
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
  )->order_by({ -desc => 'docente.qt_doc_bas' });

# Numero de escolas de Campinas ANTES de clusterizar, usado depois para
# conferir que todas (e nao um subconjunto) acabam clusterizadas.
my $expected_schools_count = $source_rs->count;

subtest qq/
$tag <preparando a tabela de staging>
  - garante que ha escolas suficientes em Campinas para o teste fazer sentido
/ => sub {
  ok $expected_schools_count >= 2,
    "encontrou pelo menos 2 escolas em Campinas ($expected_schools_count encontradas)";
};

$source_rs->save_in_table(
  tbl_name  => $table_name,
  schema    => 'staging',
  temporary => 0,
);

# --------------------------------------------------------------------------
# Aplica a clusterizacao (kmeans, mesmo caminho testado em clustering.t)
# --------------------------------------------------------------------------
my $job = run_clustering_job($t, {
  id_column  => 'co_entidade',
  table_name => $table_name,
  schema     => 'staging',
  algorithm  => 'kmeans',
  clusters   => 2,
});

subtest qq/
$tag <clusterizacao>
  - job de clusterizacao finaliza com sucesso para a tabela de Campinas
/ => sub {
  is $job->info->{state}, 'finished', 'job finalizado com sucesso'
    or diag "resultado: " . ($job->info->{result} // '');
};

# --------------------------------------------------------------------------
# Injeta a relacao dinamica direto a partir do resultado do job, exatamente
# como no sandbox_cluster_geojson.pl
# --------------------------------------------------------------------------
subtest qq/
$tag <injecao da relacao>
  - inject_cluster_class_from_job registra a classe e a relacao sem erro
/ => sub {
  my $injected_class = $sch->inject_cluster_class_from_job(
    $job->info->{result},
    'CensoEscolas',
    source_name => 'ClusterTestClusterCampinas',
  );

  ok $injected_class, 'inject_cluster_class_from_job retornou uma classe';
  is $injected_class, 'EduMaps::Schema::Result::ClusterTestClusterCampinas',
    'nome da classe injetada e o esperado';
  ok( (grep { $_ eq 'ClusterTestClusterCampinas' } $sch->sources),
    'a classe injetada aparece entre os sources do schema' );
};

# --------------------------------------------------------------------------
# Confirma que as escolas de Campinas vêm clusterizadas ao consultar
# CensoEscolas com o join na relacao recem-injetada.
# --------------------------------------------------------------------------
subtest qq/
$tag <consulta>
  - todas as escolas de Campinas aparecem com cluster_id atribuido
/ => sub {
  my @rows = $sch->resultset('CensoEscolas')
    ->search({ 'me.no_municipio' => 'Campinas' })
    ->join('cluster_info')
    ->search(undef, {
      columns => ['me.co_entidade'],
      '+select' => ['cluster_info.cluster_id'],
      '+as'     => ['cluster_id'],
    })
    ->all;

  is scalar(@rows), $expected_schools_count,
    'o join com cluster_info traz todas as escolas de Campinas (join INNER nao descarta nenhuma)';

  ok( (@rows > 0), 'pelo menos uma escola de Campinas foi retornada' );

  my @cluster_ids = map { $_->get_column('cluster_id') } @rows;

  ok( (! grep { ! defined $_ } @cluster_ids),
    'todas as escolas tem cluster_id definido (nao-nulo)' );

  my %distinct = map { $_ => 1 } @cluster_ids;
  ok( (keys %distinct) <= 2,
    'o numero de clusters distintos nao excede o k pedido (2)' );

  ok( (keys %distinct) >= 1,
    'pelo menos um cluster foi de fato formado' );
};

cleanup_job($t, $job);

$sch->storage->dbh->do("DROP TABLE IF EXISTS staging.$table_name");

done_testing;
