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
$tag <similar_to> vizinhos mais próximos pela distância entre as notas (pgvector)
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
    ok(!exists $n->{similarity}, 'sem similarity (1 - distância só valia no cosseno)');
    is(scalar @{ $n->{notas} },      6, 'seis notas da vizinha');
    is(scalar @{ $n->{notas_alvo} }, 6, 'seis notas da escola');
    my $l2 = 0;
    $l2 += ($n->{notas}[$_] - $n->{notas_alvo}[$_])**2 for 0 .. 5;
    ok(abs(sqrt($l2) - $n->{distance}) < 1e-4, 'distance = euclidiana entre as notas');
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

# #421 (AN-03): o vetor só tem as notas; a vizinha precisa dividir ao menos
# uma etapa com a escola. Três escolas de teste num município fictício: a
# creche tem o MESMO vetor da escola alvo e mesmo assim não pode aparecer.
my $INEP_ALVO    = '60001601';
my $INEP_CRECHE  = '60001602';
my $INEP_FUND    = '60001603';
my $MUNI_TESTE   = 6000016;

subtest qq/
$tag <similar_to> exige etapa em comum (#421)
/ => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_table;

  my $dbh  = $schema->storage->dbh;
  my @ids  = ($INEP_ALVO, $INEP_CRECHE, $INEP_FUND);
  my $limpa = sub {
    $dbh->do('DELETE FROM analytics.school_embedding WHERE co_entidade = ANY(?)', {}, \@ids);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?)', {}, \@ids);
  };
  $limpa->();

  my $censo = $dbh->prepare(q{
    INSERT INTO clean.censo_escolas
      (nu_ano_censo, co_entidade, no_entidade, co_municipio, tp_situacao_funcionamento,
       in_comum_creche, in_comum_fund_ai, in_comum_fund_af)
    VALUES (2025, ?, ?, ?, 1, ?, ?, ?)
  });
  $censo->execute($INEP_ALVO,   'EMEF Alvo',   $MUNI_TESTE, 0, 1, 1);
  $censo->execute($INEP_CRECHE, 'CMEI Igual',  $MUNI_TESTE, 1, 0, 0);
  $censo->execute($INEP_FUND,   'EMEF Parecida', $MUNI_TESTE, 0, 1, 0);

  my $emb = $dbh->prepare('INSERT INTO analytics.school_embedding (co_entidade, embedding) VALUES (?, ?)');
  $emb->execute($INEP_ALVO,   '[1,1,1,1,1,1]');
  $emb->execute($INEP_CRECHE, '[1,1,1,1,1,1]');
  $emb->execute($INEP_FUND,   '[1,1,1,1,1,0.5]');

  my $vizinhas = $schema->resultset('SchoolEmbedding')->similar_to($INEP_ALVO, 5, $MUNI_TESTE);
  is([map { $_->{co_entidade} } @$vizinhas], [$INEP_FUND],
    'só a escola com etapa em comum; a creche de vetor idêntico fica fora');

  # escola sem etapa no Censo não filtra (falta de dado não zera as vizinhas)
  $dbh->do('UPDATE clean.censo_escolas SET in_comum_fund_ai = NULL, in_comum_fund_af = NULL WHERE co_entidade = ?',
    {}, $INEP_ALVO);
  $vizinhas = $schema->resultset('SchoolEmbedding')->similar_to($INEP_ALVO, 5, $MUNI_TESTE);
  is(scalar @$vizinhas, 2, 'sem etapa registrada, não filtra por etapa');

  $limpa->();
};

# #487 (RL-01): o cosseno ignorava o nível. A escola com todas as notas em 5
# tinha como "idêntica" (cosseno 0) a de todas em 8; pela distância entre as
# notas, a mais próxima é a de todas em 5,5.
my $INEP_NIVEL_ALVO = '60048701';
my $INEP_NIVEL_ALTO = '60048702';
my $INEP_NIVEL_PERTO = '60048703';
my $MUNI_NIVEL = 6004871;

subtest qq/
$tag <similar_to> compara o nível das notas, não só o formato (#487)
/ => sub {
  plan skip_all => 'analytics.school_embedding ausente (pgvector nao migrado)'
    unless $has_table;

  my $dbh = $schema->storage->dbh;
  my @ids = ($INEP_NIVEL_ALVO, $INEP_NIVEL_ALTO, $INEP_NIVEL_PERTO);
  my $limpa = sub {
    $dbh->do('DELETE FROM analytics.school_embedding WHERE co_entidade = ANY(?)', {}, \@ids);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?)', {}, \@ids);
  };
  $limpa->();

  my $censo = $dbh->prepare(q{
    INSERT INTO clean.censo_escolas
      (nu_ano_censo, co_entidade, no_entidade, co_municipio, tp_situacao_funcionamento, in_comum_fund_ai)
    VALUES (2025, ?, ?, ?, 1, 1)
  });
  $censo->execute($INEP_NIVEL_ALVO,  'EMEF Cinco',       $MUNI_NIVEL);
  $censo->execute($INEP_NIVEL_ALTO,  'EMEF Oito',        $MUNI_NIVEL);
  $censo->execute($INEP_NIVEL_PERTO, 'EMEF Cinco e Meio', $MUNI_NIVEL);

  my $emb = $dbh->prepare('INSERT INTO analytics.school_embedding (co_entidade, embedding) VALUES (?, ?)');
  $emb->execute($INEP_NIVEL_ALVO,  '[5,5,5,5,5,5]');
  $emb->execute($INEP_NIVEL_ALTO,  '[8,8,8,8,8,8]');
  $emb->execute($INEP_NIVEL_PERTO, '[5.5,5.5,5.5,5.5,5.5,5.5]');

  my $vizinhas = $schema->resultset('SchoolEmbedding')->similar_to($INEP_NIVEL_ALVO, 5, $MUNI_NIVEL);
  is([map { $_->{co_entidade} } @$vizinhas], [$INEP_NIVEL_PERTO, $INEP_NIVEL_ALTO],
    'a de notas em 5,5 vem antes da de notas em 8, que tem o mesmo formato');
  ok(abs($vizinhas->[0]{distance} - 0.5 * sqrt(6)) < 1e-4, 'distância em pontos: 0,5 em cada nota');
  ok(abs($vizinhas->[1]{distance} - 3 * sqrt(6)) < 1e-4,   'distância em pontos: 3 em cada nota');

  $limpa->();
};

done_testing;
