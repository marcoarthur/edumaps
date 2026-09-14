# t/04-api/cluster.t
# Testes de API para as rotas de clusterização por geotag:
#   GET /api/cluster/regions
#   GET /api/cluster/ufs
#   GET /api/cluster/municipalities
#   GET /api/cluster/schools
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

done_testing;