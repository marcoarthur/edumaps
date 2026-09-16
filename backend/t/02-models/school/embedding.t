use strictures 2;
use lib qw(t/lib lib);
use Imports;
use open ':std', ':encoding(UTF-8)';
use utf8;
use ok 'EduMaps::Schema';

my $schema = EduMaps::Schema->go;

# analytics.school_embedding só existe onde a migration school_embedding
# (pgvector) foi aplicada; em ambientes sem a extensão, o teste é pulado.
my $has_table = $schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('analytics.school_embedding')"
);

my $tag = '[school model] embedding';

subtest qq/
$tag <similar_to> vizinhos mais próximos por cosseno (pgvector)
/ => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_table;

  my $dbh = $schema->storage->dbh;
  my $rs  = $schema->resultset('SchoolEmbedding');

  # escola alvo: com embedding e presente no censo (para o join de município)
  my $target = $dbh->selectrow_array(
    "SELECT s.co_entidade FROM analytics.school_embedding s "
    . "JOIN clean.censo_escolas ce ON ce.co_entidade = s.co_entidade "
    . "AND ce.tp_situacao_funcionamento = 1 LIMIT 1"
  );

  ok($target, 'existe escola com embedding') or return;

  my $municipio = $dbh->selectrow_array(
    'SELECT co_municipio FROM clean.censo_escolas WHERE co_entidade = ?',
    undef, $target
  );

  my $neighbors = $rs->similar_to($target, 5, $municipio);

  is(ref $neighbors, 'ARRAY', 'similar_to devolve arrayref');
  ok(scalar(@$neighbors) > 0, 'retorna vizinhos');
  ok(scalar(@$neighbors) <= 5, 'respeita o limite');

  my $prev = -1;
  for my $n (@$neighbors) {
    isnt($n->{co_entidade}, $target, 'nao inclui a propria escola');
    ok(defined $n->{distance},   'tem distance');
    ok(defined $n->{similarity}, 'tem similarity');
    ok(
      abs(($n->{similarity} + $n->{distance}) - 1) < 1e-9,
      'similarity = 1 - distance'
    );
    ok(
      $n->{similarity} >= 0 && $n->{similarity} <= 1,
      'similarity no intervalo [0, 1]'
    );
    cmp_ok($n->{distance}, '>=', $prev, 'ordenado por distancia crescente');
    $prev = $n->{distance};
  }

  # o filtro por município mantém a semântica "similar na mesma cidade"
  my $censo = $schema->resultset('CensoEscolas');
  for my $n (@$neighbors) {
    my $muni = $censo->search({ co_entidade => $n->{co_entidade} })
      ->get_column('co_municipio')->first;
    is($muni, $municipio, "vizinho $n->{co_entidade} pertence ao municipio");
  }
};

done_testing;
