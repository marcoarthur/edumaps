# t/02-models/antt_geolocalizacao.t
# #168: localização do acidente da ANTT pelos marcos de km e chegada à escola.
#
# O acidente só traz trecho ('BR-393/RJ') e km. clean.antt_geolocalizar_acidentes()
# põe o ponto (marco exato ou interpolação entre marcos vizinhos) e o município
# (polígono da malha que contém o ponto). Confere, contra o banco real e numa
# transação desfeita no fim:
#
#   1. cada situação do balanço (marco, interpolado, sem_marco, sem_km,
#      trecho_ilegivel, fora_da_malha) — nenhum acidente some sem ser contado;
#   2. o município vem do ponto, e ponto fora da malha NÃO ganha município;
#   3. a view analytics.mobilidade_escola passa a contar o acidente no
#      município, sem multiplicar linhas (uma linha por escola, #168).
use lib qw(t/lib lib);
use Imports;
use EduMaps::Schema;
use utf8;

my $dbh = EduMaps::Schema->go->storage->dbh;

skip_all('função clean.antt_geolocalizar_acidentes ausente (migração não aplicada)')
  unless $dbh->selectrow_array(
    q{SELECT to_regprocedure('clean.antt_geolocalizar_acidentes(numeric)') IS NOT NULL});

# Um município que tenha escola na view, e um ponto dentro dele.
my ($ibge, $x, $y) = $dbh->selectrow_array(q{
  SELECT m.codigo_ibge, ST_X(ST_PointOnSurface(m.geometry)), ST_Y(ST_PointOnSurface(m.geometry))
    FROM clean.malha_municipio m
   WHERE EXISTS (SELECT 1 FROM analytics.mv_mobilidade_escola v WHERE v.codigo_ibge::text = m.codigo_ibge)
   ORDER BY m.codigo_ibge LIMIT 1
});
skip_all('nenhum município com escola na malha do banco') unless $ibge;

$dbh->begin_work;
my $ok = eval {
  # Marcos de teste. Rodovia fictícia (BR-999) para não colidir com dado real.
  # km 100 e 101 a ~10 m um do outro, dentro do município; km 200 e 205
  # (lacuna maior que a tolerância de 2 km); BR-998 no mar (fora da malha).
  my $marco = $dbh->prepare(q{
    INSERT INTO clean.antt_marco_km (rodovia, uf, km, geom)
    VALUES (?, ?, ?, ST_SetSRID(ST_MakePoint(?, ?), 4674))});
  $marco->execute('BR-999', 'RJ', 100, $x, $y);
  $marco->execute('BR-999', 'RJ', 101, $x + 0.0001, $y);
  $marco->execute('BR-999', 'RJ', 200, $x, $y);
  $marco->execute('BR-999', 'RJ', 205, $x, $y);
  $marco->execute('BR-998', 'ES', 300, -30, -20);
  $marco->execute('BR-998', 'ES', 301, -30.0001, -20);

  my $acid = $dbh->prepare(q{
    INSERT INTO clean.antt_acidente_trecho
      (concessionaria, data_acidente, horario, n_ocorrencia, trecho, km, mortos)
    VALUES ('TESTE-168', CURRENT_DATE - 10, '10:00', ?, ?, ?, ?)
    RETURNING id_acidente});
  my %id;
  for my $a (
    [ marco         => 'BR-999/RJ', 100,   1 ],
    [ interpolado   => 'BR-999/RJ', 100.5, 0 ],
    [ marco_variante=> 'BR 999 / RJ', 101, 0 ],
    [ acima         => 'BR-999/RJ', 210,   0 ],
    [ abaixo        => 'BR-999/RJ', 50,    0 ],
    [ lacuna        => 'BR-999/RJ', 202,   0 ],
    [ estadual      => 'SP-330/SP', 10,    0 ],
    [ sem_km        => 'BR-999/RJ', undef, 0 ],
    [ mar           => 'BR-998/ES', 300.5, 0 ],
  ) {
    my ($nome, $trecho, $km, $mortos) = @$a;
    $acid->execute($nome, $trecho, $km, $mortos);
    ($id{$nome}) = $acid->fetchrow_array;
  }

  my %balanco = map { @$_ } @{ $dbh->selectall_arrayref(
    q{SELECT situacao, n FROM clean.antt_geolocalizar_acidentes()}) };
  is \%balanco, {
    marco => 2, interpolado => 1, sem_marco => 3,
    trecho_ilegivel => 1, sem_km => 1, fora_da_malha => 1,
  }, 'balanço conta cada acidente numa situação';

  my $linha = sub {
    $dbh->selectrow_hashref(q{
      SELECT rodovia, uf, geo_metodo, codigo_ibge, ST_X(geom) AS x, ST_Y(geom) AS y
        FROM clean.antt_acidente_trecho WHERE id_acidente = ?}, undef, $id{ $_[0] });
  };

  my $m = $linha->('marco');
  is [ @$m{qw(rodovia uf geo_metodo codigo_ibge)} ], [ 'BR-999', 'RJ', 'marco', $ibge ],
    'km com marco: ponto do marco e município do polígono';

  my $i = $linha->('interpolado');
  is $i->{geo_metodo}, 'interpolado', 'km entre marcos vizinhos é interpolado';
  ok abs($i->{x} - ($x + 0.00005)) < 1e-9 && abs($i->{y} - $y) < 1e-9,
    'ponto interpolado fica a meio caminho dos dois marcos';
  is $i->{codigo_ibge}, $ibge, 'interpolado ganha o município';

  is $linha->('marco_variante')->{rodovia}, 'BR-999', 'trecho "BR 999 / RJ" é normalizado';

  for my $n (qw(acima abaixo lacuna)) {
    my $r = $linha->($n);
    ok !defined $r->{geo_metodo} && !defined $r->{codigo_ibge},
      "$n: sem marco dos dois lados (ou lacuna > 2 km) fica sem ponto e sem município";
  }
  is $linha->('estadual')->{rodovia}, undef, 'rodovia estadual não é lida como BR';

  my $mar = $linha->('mar');
  ok defined $mar->{geo_metodo} && !defined $mar->{codigo_ibge},
    'ponto fora da malha fica sem município (nunca por aproximação)';

  # A view: acidentes contados no município do acidente, sem fan-out.
  my $n_antes = $dbh->selectrow_array(q{SELECT count(*) FROM analytics.mv_mobilidade_escola});
  $dbh->do(q{REFRESH MATERIALIZED VIEW analytics.mv_mobilidade_escola});
  my $n_depois = $dbh->selectrow_array(q{SELECT count(*) FROM analytics.mv_mobilidade_escola});
  is $n_depois, $n_antes, 'uma linha por escola depois de carregar acidentes (sem fan-out)';

  my $v = $dbh->selectall_arrayref(q{
    SELECT DISTINCT acidentes_12m, acidentes_fatais_12m, pct_acidentes_fatais
      FROM analytics.mv_mobilidade_escola WHERE codigo_ibge::text = ?}, undef, $ibge);
  is $v, [ [ 3, 1, '33.33' ] ], 'escolas do município contam os 3 acidentes localizados, 1 com morto';

  my $outros = $dbh->selectrow_array(q{
    SELECT count(*) FROM analytics.mv_mobilidade_escola
     WHERE codigo_ibge::text <> ? AND acidentes_12m IS DISTINCT FROM 0}, undef, $ibge);
  is $outros, 0, 'demais municípios: zero real (a fonte tem dado), não NULL';
  1;
};
my $erro = $@;
$dbh->rollback;
fail("erro no teste: $erro") unless $ok;

done_testing;
