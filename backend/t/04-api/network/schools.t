# t/04-api/network/schools.t
# Testes de integração para API da rede de escolas (schools)
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $path = "/api/network/3550308/schools";

subtest '[API Network] schools - validações' => sub {
  # rede inválida
  $t->get_ok("$path?rede=nao_existe")->status_is(400);

  # limit inválido
  $t->get_ok("$path?limit=abc")->status_is(400);

  # município sem dados
  $t->get_ok("/api/network/9999999/schools")->status_is(404);
};

subtest '[API Network] schools - contrato' => sub {
  my $tx = $t->get_ok("$path?rede=municipal&limit=5")->status_is(200)->tx;
  my $json = $tx->res->json;

  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Possui escolas');
  ok($json->@* <= 5, 'Respeita o limite');

  for my $school ($json->@*) {
    ok(exists $school->{co_entidade}, 'Campo co_entidade presente');
    ok(exists $school->{no_entidade}, 'Campo no_entidade presente');
    is($school->{tp_dependencia}, 3, 'Rede municipal (tp_dependencia=3)');
    ok(exists $school->{matricula_qt_mat_bas}, 'Campo matricula presente');
  }
};

# ------------------------------------------------------------
# GET /api/cluster/schools
# ------------------------------------------------------------
subtest 'GET /api/cluster/schools: retorna FeatureCollection com cluster_id' => sub {
  # Garante as colunas (job de clusterização pode não ter rodado no dev).
  # A leitura vem de clean.school_indicators (tabela denormalizada).
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_id INTEGER');
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_label TEXT');
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_rank INTEGER');
  $dbh->do(q{
    UPDATE clean.school_indicators
       SET cluster_id = 1, cluster_label = 'Alta qualidade de infraestrutura', cluster_rank = 3
     WHERE co_municipio = 3550308
  });

  my $tx = $t->get_ok('/api/cluster/schools' => form => {
    codigo_uf     => 35,
    codigo_ibge   => 3550308,
  })->status_is(200)->tx;
  my $json = $tx->res->json;

  is $json->{type}, 'FeatureCollection', 'É um FeatureCollection';
  ok(ref($json->{features}) eq 'ARRAY', 'Possui array de features');

  my $n = @{ $json->{features} };
  ok($n >= 1, 'Possui ao menos 1 feature (n=' . $n . ')');
  like $json->{features}[0]->{properties}{cluster_id} => qr/^\d+$/, 'cluster_id numérico';
  is $json->{features}[0]->{properties}{cluster_label}, 'Alta qualidade de infraestrutura', 'cluster_label semântico';
  like $json->{features}[0]->{properties}{cluster_rank} => qr/^\d+$/, 'cluster_rank numérico';

  $dbh->do('UPDATE clean.school_indicators SET cluster_id = NULL, cluster_label = NULL, cluster_rank = NULL WHERE co_municipio = 3550308');
  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_id');
  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_label');
  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_rank');
};

subtest 'GET /api/cluster/schools: sem cluster_id -> 404 + erro' => sub {
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_id INTEGER');
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_label TEXT');
  $dbh->do('ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS cluster_rank INTEGER');

  $t->get_ok('/api/cluster/schools' => form => {codigo_regiao => 1})->status_is(404);

  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_id');
  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_label');
  $dbh->do('ALTER TABLE clean.school_indicators DROP COLUMN IF EXISTS cluster_rank');
};

done_testing;