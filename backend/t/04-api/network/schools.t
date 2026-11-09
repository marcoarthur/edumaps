# t/04-api/network/schools.t
# Testes de integração para API da rede de escolas (schools)
use lib qw(t/lib lib);
use Imports;
use CI;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

# /api/cluster/schools lê clean.school_indicators, que só o job de
# clusterização preenche: os subtestes de cluster montam a própria fixture numa
# transação desfeita no fim (ver com_fixture_de_cluster).

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
#
# clean.school_indicators nasce vazia e é preenchida pelo job de
# clusterização, que também cria as colunas cluster_*. O teste monta a própria
# fixture numa transação desfeita no fim: a requisição usa a mesma conexão, e
# nada do banco (linhas, colunas, clusters já calculados) é alterado.
# ------------------------------------------------------------
my $dbh = $t->app->schema->storage->dbh;

sub com_fixture_de_cluster ($cb) {
  $dbh->begin_work;
  my $ok = eval {
    $dbh->do("ALTER TABLE clean.school_indicators ADD COLUMN IF NOT EXISTS $_")
      for 'cluster_id INTEGER', 'cluster_label TEXT', 'cluster_rank INTEGER';
    $cb->();
    1;
  };
  my $err = $@;
  $dbh->rollback;
  die $err unless $ok;
}

subtest 'GET /api/cluster/schools: retorna FeatureCollection com cluster_id' => sub {
  com_fixture_de_cluster(sub {
    # Duas escolas de São Paulo copiadas do censo (as colunas do censo são as
    # primeiras da tabela), com cluster atribuído.
    my %si = map { $_ => 1 } @{ $dbh->selectcol_arrayref(q{
      SELECT column_name FROM information_schema.columns
       WHERE table_schema = 'clean' AND table_name = 'school_indicators'
    }) };
    my $cols = join ', ', grep { $si{$_} } @{ $dbh->selectcol_arrayref(q{
      SELECT column_name FROM information_schema.columns
       WHERE table_schema = 'clean' AND table_name = 'censo_escolas'
       ORDER BY ordinal_position
    }) };
    $dbh->do("DELETE FROM clean.school_indicators WHERE co_municipio = 3550308");
    my $n = $dbh->do(qq{
      INSERT INTO clean.school_indicators ($cols)
      SELECT $cols FROM clean.censo_escolas
       WHERE co_municipio = 3550308 AND latitude IS NOT NULL AND longitude IS NOT NULL
       ORDER BY co_entidade LIMIT 2
    });
    $dbh->do(q{
      UPDATE clean.school_indicators
         SET cluster_id = 1, cluster_label = 'Alta qualidade de infraestrutura', cluster_rank = 3
       WHERE co_municipio = 3550308
    });
    cmp_ok $n, '>=', 1, "fixture com escolas de São Paulo (n=$n)";

    my $json = $t->get_ok('/api/cluster/schools' => form => {
      codigo_uf   => 35,
      codigo_ibge => 3550308,
    })->status_is(200)->tx->res->json;

    is $json->{type}, 'FeatureCollection', 'É um FeatureCollection';
    is ref $json->{features}, 'ARRAY', 'Possui array de features';
    is scalar @{ $json->{features} // [] }, $n, 'uma feature por escola da fixture';
    my $p = $json->{features}[0]{properties};
    like $p->{cluster_id}, qr/^\d+$/, 'cluster_id numérico';
    is $p->{cluster_label}, 'Alta qualidade de infraestrutura', 'cluster_label semântico';
    like $p->{cluster_rank}, qr/^\d+$/, 'cluster_rank numérico';
  });
};

subtest 'GET /api/cluster/schools: sem cluster_id -> 404 + erro' => sub {
  com_fixture_de_cluster(sub {
    # Na transação, nenhuma escola da região 1 tem cluster.
    $dbh->do('UPDATE clean.school_indicators SET cluster_id = NULL WHERE co_regiao = 1');
    $t->get_ok('/api/cluster/schools' => form => {codigo_regiao => 1})
      ->status_is(404)
      ->json_like('/error' => qr/Nenhuma escola com cluster/);
  });
};

done_testing;