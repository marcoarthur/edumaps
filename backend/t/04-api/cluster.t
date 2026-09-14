# t/04-api/cluster.t
# Testes de API para as rotas de clusterização por geotag:
#   GET /api/cluster/regions
#   GET /api/cluster/ufs
#   GET /api/cluster/municipalities
#   GET /api/cluster/schools
#   GET /api/cluster/presets
#   GET /api/cluster/columns
#   GET /api/cluster/years
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

subtest 'GET /api/cluster/regions: lista as 5 regiões' => sub {
  my $tx = $t->get_ok('/api/cluster/regions')->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  is scalar($json->@*), 5, '5 regiões do Brasil';
  ok(defined $json->[0]->{co_regiao}, 'co_regiao presente');
  ok(defined $json->[0]->{no_regiao}, 'no_regiao presente');
};

subtest 'GET /api/cluster/ufs: filtra por região' => sub {
  my $tx = $t->get_ok('/api/cluster/ufs' => form => {codigo_regiao => 1})->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Ao menos 1 UF');
  is $json->[0]->{co_uf}, '11', 'primeira UF da região Norte é RO (11)';
  is $json->[0]->{sg_uf}, 'RO', 'sigla RO';
};

subtest 'GET /api/cluster/ufs: região inválida -> 400' => sub {
  $t->get_ok('/api/cluster/ufs' => form => {codigo_regiao => 9})->status_is(400);
};

subtest 'GET /api/cluster/municipalities: filtra por UF' => sub {
  my $tx = $t->get_ok('/api/cluster/municipalities' => form => {codigo_uf => 35})->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Ao menos 1 município');
  ok(defined $json->[0]->{co_municipio}, 'co_municipio presente');
  ok(defined $json->[0]->{no_municipio}, 'no_municipio presente');
};

subtest 'GET /api/cluster/schools: sem codigo_* válido -> 400' => sub {
  $t->get_ok('/api/cluster/schools' => form => {codigo_ibge => 'x'})->status_is(400);
};

subtest 'GET /api/cluster/schools: recorte sem cluster gerado -> 404' => sub {
  # UF 00 não existe no censo — garante 404 sem reescrever a tabela
  $t->get_ok('/api/cluster/schools' => form => {codigo_uf => '00'})->status_is(404);
};

subtest 'GET /api/cluster/presets: lista os 3 presets curados' => sub {
  my $tx = $t->get_ok('/api/cluster/presets')->status_is(200)->tx;
  my $json = $tx->res->json;
  is scalar($json->@*), 3, '3 presets';
  my %by_id = map { $_->{id} => $_ } @$json;
  ok(defined $by_id{desempenho}, 'preset desempenho');
  ok(defined $by_id{docencia}, 'preset docencia');
  ok(defined $by_id{infraestrutura}, 'preset infraestrutura');
  ok($by_id{desempenho}->{year_filter} == 1, 'desempenho exige ano');
  ok($by_id{docencia}->{year_filter} == 0, 'docencia independente de ano');
  is $by_id{infraestrutura}->{features}->[0], 'in_agua_potavel', 'feature de infraestrutura';
  is $by_id{desempenho}->{features}->[0], 'nota_media', 'feature de desempenho';
  is $by_id{docencia}->{features}->[0], 'prop_licenciatura', 'feature de docência';

  # Metadados de rótulo semântico (conceito + gênero + polaridade)
  is $by_id{infraestrutura}->{concept}, 'qualidade de infraestrutura', 'conceito de infraestrutura';
  is $by_id{infraestrutura}->{gender}, 'f', 'infraestrutura feminino';
  is $by_id{infraestrutura}->{directions}->{in_agua_potavel}, 1, 'infraestrutura: direção positiva';
  is $by_id{docencia}->{concept}, 'qualidade da docência', 'conceito de docência';
  is $by_id{docencia}->{directions}->{prop_sem_especializacao}, -1, 'docência: sem especialização é negativa';
  is $by_id{desempenho}->{gender}, 'm', 'desempenho masculino';
};

subtest 'GET /api/cluster/columns: cataloga colunas de school_indicators' => sub {
  my $tx = $t->get_ok('/api/cluster/columns')->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 300, 'lista completa do censo + docentes + IDEB (~325)');
  my %by_name = map { $_->{column_name} => $_ } @$json;
  ok(defined $by_name{co_entidade}, 'co_entidade presente');
  is $by_name{co_entidade}->{table_name}, 'censo_escolas', 'co_entidade vem do censo';
  ok(defined $by_name{nota_media}, 'nota_media presente');
  is $by_name{nota_media}->{table_name}, 'ideb_notas_escolas', 'nota_media vem do IDEB';
  ok(defined $by_name{prop_licenciatura}, 'prop_licenciatura presente');
  is $by_name{prop_licenciatura}->{table_name}, 'censo_docentes', 'prop_licenciatura vem de docentes';
  ok(length($by_name{prop_licenciatura}->{comment}) > 0, 'comment de prop_licenciatura preenchido');
  ok(length($by_name{ano_ideb}->{comment}) > 0, 'comment de ano_ideb preenchido');
};

subtest 'GET /api/cluster/years: anos IDEB disponíveis em ordem decrescente' => sub {
  my $tx = $t->get_ok('/api/cluster/years')->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Ao menos 1 ano');
  my @anos = sort { $b <=> $a } map { $_->{ano} } @$json;
  my @payload = map { $_->{ano} } @$json;
  is \@payload, \@anos, 'anos em ordem decrescente';
};

subtest 'GET /api/cluster/summary: rótulo semântico do último run' => sub {
  my $dbh = $t->app->schema->storage->dbh;
  # A tabela de metadados é self-provisioned pelo motor R; garante existência.
  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS analytics.clustering_metadata (
      run_id text, algorithm text, target_table text, params_json jsonb,
      cluster_id integer, cluster_size integer, is_noise boolean,
      centroids text, extra_metrics text
    )
  });

  # run_id lexicograficamente maior que "run_<epoch>" -> vira o run mais recente.
  my $run_id = 'zzz_test_' . time;
  $dbh->do(
    'INSERT INTO analytics.clustering_metadata
       (run_id, algorithm, target_table, params_json, cluster_id, cluster_size, is_noise, centroids, extra_metrics)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    undef,
    $run_id, 'kmeans', 'clean.school_indicators', '{}', 1, 42, 0,
    '{"in_biblioteca":0.9,"in_internet":0.8}',
    '{"cluster_label":"Alta qualidade de infraestrutura","cluster_rank":3}',
  );

  my $tx = $t->get_ok('/api/cluster/summary')->status_is(200)->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  my ($row) = grep { $_->{cluster_id} == 1 } @$json;
  ok(defined $row, 'cluster 1 presente no resumo');
  is $row->{cluster_label}, 'Alta qualidade de infraestrutura', 'rótulo semântico';
  is $row->{cluster_rank}, 3, 'rank do cluster';
  is $row->{cluster_size}, 42, 'tamanho do cluster';
  is $row->{indicators}->{in_biblioteca}, 0.9, 'indicador do centroide';

  $dbh->do('DELETE FROM analytics.clustering_metadata WHERE run_id = ?', undef, $run_id);
};

done_testing;