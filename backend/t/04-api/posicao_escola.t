# t/04-api/posicao_escola.t
# #506: a posição da escola (/api/school/:inep/ranking).
#   RC-01: "acima de X%" conta só as escolas com valor menor; o empate vem
#          em cada escopo (empate = escolas com o mesmo valor, contando a
#          própria; abaixo = escolas com valor menor).
#   RC-02: no IDEB, só escolas em funcionamento no Censo mais recente.
# Pelo cálculo ao vivo (sem linha no ranking pré-calculado) e pela tabela
# (depois do bin/ranking.pl --source ideb). Município fictício 6005061.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $MUN = 6005061;
# inep,       IDEB 2023, situação no Censo (1 = em funcionamento, 3 = extinta)
my @ESC = (
  ['60050601', 6.0, 1],
  ['60050602', 6.0, 1],
  ['60050603', 6.0, 1],
  ['60050604', 5.0, 1],
  ['60050605', 4.0, 1],
  ['60050606', 9.0, 3],   # extinta: fora da posição e do total
);
my @INEPS = map { $_->[0] } @ESC;
my $ph = join ',', ('?') x @INEPS;
my $limpa = sub {
  $dbh->do("DELETE FROM analytics.ranking_escola WHERE id_escola IN ($ph)", {}, @INEPS);
  $dbh->do("DELETE FROM clean.ideb_notas_escolas WHERE id_escola IN ($ph)", {}, @INEPS);
  $dbh->do("DELETE FROM clean.censo_escolas WHERE co_entidade IN ($ph)", {}, @INEPS);
};
$limpa->();
END { $limpa->() }

my ($ano_censo) = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas');
$ano_censo //= 2025;
my $censo = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, co_uf,
   tp_situacao_funcionamento, in_comum_fund_ai)
  VALUES (?, ?, ?, 3, ?, 'Posicao do Teste', 'XW', 60, ?, 1)});
my $ideb = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas
  (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa, ideb_observado)
  VALUES (?, 'XW', ?, 'Posicao do Teste', 'Escola', 'Municipal', 2023, 'fundamental_i', ?)});
for my $e (@ESC) {
  my ($inep, $v, $sit) = @$e;
  $censo->execute($ano_censo, $inep, "Escola $inep", $MUN, $sit);
  $ideb->execute($inep, $MUN, $v);
}

my $mun = sub ($inep) {
  $t->get_ok("/api/school/$inep/ranking?indicador=ideb_anos_iniciais")->status_is(200)
    ->tx->res->json->{ranking}{municipio};
};

my $confere = sub ($origem) {
  my $topo = $mun->('60050601');
  is [ @$topo{qw(posicao total empate abaixo percentil)} ], [1, 5, 3, 2, 50],
    "$origem: 1º de 5, empatada com mais 2, acima de 2 das 4 outras (50%)";
  is $mun->('60050603')->{posicao}, 1, "$origem: as três empatadas dividem o 1º";

  is [ @{ $mun->('60050604') }{qw(posicao empate abaixo percentil)} ], [4, 1, 1, 25],
    "$origem: 4º, sem empate, acima de 1 (25%)";
  is [ @{ $mun->('60050605') }{qw(posicao abaixo percentil)} ], [5, 0, 0],
    "$origem: a última fica acima de 0% (antes: (5 − 5)/(5 − 1) = 0, igual)";

  $t->get_ok('/api/school/60050606/ranking?indicador=ideb_anos_iniciais')
    ->status_is(404, "$origem: escola extinta sem posição no IDEB");
};

subtest 'cálculo ao vivo (sem linha pré-calculada)' => sub {
  $dbh->do("DELETE FROM analytics.ranking_escola WHERE id_escola IN ($ph)", {}, @INEPS);
  $confere->('ao vivo');
};

subtest 'tabela pré-calculada (bin/ranking.pl --source ideb)' => sub {
  my $saida = qx{$^X -Ilib bin/ranking.pl --source ideb 2>&1};
  is $? >> 8, 0, 'ranking.pl roda' or diag $saida;
  my ($n, $emp) = $dbh->selectrow_array(q{
    SELECT count(*), max(empate_municipio) FROM analytics.ranking_escola
     WHERE indicador_id = 'ideb_anos_iniciais' AND rede = 'todas' AND id_escola IN (60050601, 60050602, 60050603, 60050604, 60050605, 60050606)});
  is $n, 5, 'cinco linhas: a extinta fica fora';
  is $emp, 3, 'empate gravado no município';
  $confere->('tabela');
};

subtest 'a nota mínima empatada não fica "acima" de ninguém (RC-01)' => sub {
  require EduMaps::Model::Rank::School;
  # sustentabilidade 0 no Brasil: 128.377º de 180.540, empatada com 52.164
  my $e = EduMaps::Model::Rank::School::_escopo_posicao(128377, 180540, 52164);
  is [ @$e{qw(abaixo percentil)} ], [0, 0], 'abaixo 0, acima de 0% (antes 29%)';
  my $u = EduMaps::Model::Rank::School::_escopo_posicao(1, 100, undef);
  is [ @$u{qw(empate abaixo percentil)} ], [1, 99, 100], 'sem empate gravado: vale 1, como antes';
};

done_testing;
