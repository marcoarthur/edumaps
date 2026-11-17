# t/04-api/network/performance.t
# Testes de integração para API da rede de escolas (performance / markers)
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $path = "/api/network/3550308";

subtest '[API Network] performance - validações' => sub {
  # rede inválida
  $t->get_ok($path . '/performance?rede=nao_existe')->status_is(400);

  # etapa inválida
  $t->get_ok($path . '/performance?etapa=inexistente')->status_is(400);

  # desde fora do range
  $t->get_ok($path . '/performance?desde=1900')->status_is(400);

  # município sem dados
  $t->get_ok('/api/network/9999999/performance')->status_is(404);
};

subtest '[API Network] performance - contrato' => sub {
  my $tx = $t->get_ok($path . '/performance')->status_is(200)->tx;
  my $json = $tx->res->json;

  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  ok($json->@* >= 1, 'Possui resultados');

  for my $perf ($json->@*) {
    ok(exists $perf->{rede}, 'Campo rede presente');
    ok(exists $perf->{etapa}, 'Campo etapa presente');
    ok(exists $perf->{ano}, 'Campo ano presente');
    ok(exists $perf->{numero_escolas}, 'Campo numero_escolas presente');
    ok(exists $perf->{ideb_medio}, 'Campo ideb_medio presente');
  }
};

subtest '[API Network] performance - filtros' => sub {
  my $tx = $t->get_ok(
    $path . '/performance?rede=estadual&etapa=fundamental_ii&desde=2015'
  )->status_is(200)->tx;
  my $json = $tx->res->json;

  ok($json->@* >= 1, 'Possui resultados filtrados');
  is($json->[0]{rede}, 'Estadual', 'Rede filtrada');
  is($json->[0]{etapa}, 'fundamental_ii', 'Etapa filtrada');
};

subtest '[API Network] markers - GeoJSON' => sub {
  my $tx = $t->get_ok($path . '/markers?rede=municipal')->status_is(200)->tx;
  my $json = $tx->res->json;

  is($json->{type}, 'FeatureCollection', 'É FeatureCollection');
  ok(ref($json->{features}) eq 'ARRAY', 'Possui features');
};

# #479 (RP-03): numero_escolas conta só as escolas com IDEB, as da média.
subtest '[API Network] performance - numero_escolas com IDEB (#479)' => sub {
  my $dbh = $t->app->schema->storage->dbh;
  my $json = $t->get_ok($path . '/performance')->status_is(200)->tx->res->json;
  my ($p) = grep { defined $_->{ideb_medio} } $json->@*;
  SKIP: {
    skip 'sem IDEB no município', 1 unless $p;
    my ($n) = $dbh->selectrow_array(q{SELECT count(ideb_observado) FROM clean.ideb_notas_escolas
      WHERE co_municipio = 3550308 AND rede = ? AND etapa = ? AND ano = ?}, undef, @$p{qw(rede etapa ano)});
    is $p->{numero_escolas}, $n, "$p->{rede} · $p->{etapa} · $p->{ano}: $n escolas com IDEB";
  }
};

done_testing;