# t/04-api/ranking_atendimento.t
# #535 (QO-01 da P5): taxa de atendimento da educação infantil no ranking de
# redes. As matrículas vêm da analytics.mv_rede_escolas das fixtures (não se
# insere escola numa MV); a população por idade é de teste, gravada em
# clean.ibge_agregados para municípios das fixtures que nenhum outro teste
# usa com a tabela 9514 (RO e Taquarituba, SP).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use POSIX ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

# município => [0 a 3, 4 e 5]
my %POP = ('1100015' => [1000, 500], '1100205' => [400, 600], '3553807' => [2000, 700]);
my @COD = sort keys %POP;

my ($ja_tem) = $dbh->selectrow_array(
  q{SELECT count(*) FROM clean.ibge_agregados WHERE tabela_id = '9514' AND codigo_ibge = ANY(?)}, undef, \@COD);
plan skip_all => 'Carga real da tabela 9514 nestes municípios: o teste não sobrescreve' if $ja_tem;

my $limpa = sub {
  $dbh->do(q{DELETE FROM clean.ibge_agregados WHERE tabela_id = '9514' AND codigo_ibge = ANY(?)}, undef, \@COD);
};
END { $limpa->() if $dbh }
my $ins = $dbh->prepare(q{INSERT INTO clean.ibge_agregados (codigo_ibge, ano, tabela_id, variavel, classificacao, valor, unidade)
                          VALUES (?, 2022, '9514', '93', ?, ?, 'Pessoas')});
for my $c (@COD) {
  my ($a, $b) = @{ $POP{$c} };
  # 0 a 3 = 4 idades de a/4; 4 e 5 = 2 idades de b/2
  $ins->execute($c, $_, $a / 4) for ('Menos de 1 ano', '1 ano', '2 anos', '3 anos');
  $ins->execute($c, $_, $b / 2) for ('4 anos', '5 anos');
}

# Matrículas das fixtures, por município: todas as redes, a municipal e as conveniadas.
sub mat ($cod, $etapa) {
  return $dbh->selectrow_array(qq{
    SELECT sum(matriculas_$etapa), COALESCE(sum(matriculas_$etapa) FILTER (WHERE codigo_rede = 3), 0),
           COALESCE(sum(matriculas_${etapa}_conveniada) FILTER (WHERE codigo_rede = 4), 0)
      FROM analytics.mv_rede_escolas WHERE co_municipio = ?}, undef, $cod);
}

subtest 'creche em RO: taxa, posição da menor para a maior e a meta' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=RO')->status_is(200)->tx->res->json;
  is $r->{tipo}, 'atendimento', 'leitura da taxa de atendimento';
  is $r->{indicador}{idade}, '0 a 3 anos', 'idade da etapa';
  is $r->{ano}, 2022, 'ano da população (Censo Demográfico)';
  is $r->{ordem}, 'menor_primeiro', 'menor primeiro (B1)';
  is $r->{total}, 2, 'os dois municípios de RO das fixtures';
  my %m = map { $_->{codigo_ibge} => $_ } @{ $r->{redes} };
  my ($todas, $mun) = mat('1100015', 'creche');
  is $m{1100015}{criancas}, 1000, 'crianças de 0 a 3 anos';
  is $m{1100015}{matriculas}, $todas, 'matrículas de todas as redes';
  cmp_ok abs($m{1100015}{taxa} - $todas / 1000), '<', 1e-4, 'taxa = matrículas / crianças';
  is $m{1100015}{taxa}, $m{1100015}{media}, 'media = taxa (ordem e destaque genéricos)';
  ok !defined $m{1100015}{teto}, 'sem conveniadas, sem teto';
  is $m{1100205}{taxa}, 0, 'sem creche: 0';
  is $m{1100205}{posicao}, 1, 'a menor taxa é a 1ª';
  is $m{1100015}{posicao}, 2, 'a maior é a última';
  is $r->{meta}{valor}, 0.5, 'meta da creche: 50%';
  is $r->{meta}{abaixo}, scalar(grep { $_->{taxa} < 0.5 } values %m), 'quantos abaixo da meta';
  ok $m{1100205}{abaixo_meta}, 'marcado abaixo da meta';
  # #547: vagas que faltam = meta × crianças (para cima) − matrículas; 0 se atingiu
  for my $c (keys %m) {
    my $alvo = POSIX::ceil(0.5 * $m{$c}{criancas} - 1e-9);
    my $esp = $alvo > $m{$c}{matriculas} ? $alvo - $m{$c}{matriculas} : 0;
    is $m{$c}{vagas_faltam_meta}, $esp, "vagas que faltam em $c (#547)";
  }
  is $m{1100205}{vagas_faltam_meta}, 200, 'sem creche: metade das 400 crianças';
  my $soma = 0; $soma += $_->{vagas_faltam_meta} for values %m;
  is $r->{meta}{vagas_faltam}, $soma, 'soma do recorte (#547)';
  ok !exists $r->{minimo_escolas} && !exists $r->{atipico}, 'sem mínimo de escolas nem salto atípico';
  is $m{1100015}{rede_local}, 'municipal', 'rede local fora do DF: a municipal (#545)';
};

subtest 'pré-escola: pode passar de 100%' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_pre&uf=RO')->status_is(200)->tx->res->json;
  my %m = map { $_->{codigo_ibge} => $_ } @{ $r->{redes} };
  my ($todas) = mat('1100015', 'pre');
  cmp_ok abs($m{1100015}{taxa} - $todas / 500), '<', 1e-4, 'taxa da pré-escola';
  is $r->{meta}{valor}, 1, 'meta da pré-escola: 100%';
  ok !$m{1100015}{abaixo_meta}, 'acima de 100% não está abaixo da meta' if $m{1100015}{taxa} >= 1;
  is $m{1100015}{vagas_faltam_meta}, 0, 'meta atingida: 0 vagas (#547)' if $m{1100015}{taxa} >= 1;
};

subtest 'teto com as conveniadas (Taquarituba, SP)' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=SP')->status_is(200)->tx->res->json;
  my ($m) = grep { $_->{codigo_ibge} eq '3553807' } @{ $r->{redes} };
  my ($todas, $mun, $conv) = mat('3553807', 'creche');
  ok $conv > 0, 'a fixture tem conveniadas';
  cmp_ok abs($m->{taxa_municipal} - $mun / 2000), '<', 1e-4, 'rede municipal';
  cmp_ok abs($m->{teto} - ($mun + $conv) / 2000), '<', 1e-4, 'municipal + conveniadas';
  is $m->{matriculas_conveniadas}, $conv, 'matrículas conveniadas';
};

subtest 'recortes e destaque' => sub {
  my $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&regiao=N&destaque=1100015')->status_is(200)->tx->res->json;
  ok((grep { $_->{codigo_ibge} eq '1100015' } @{ $r->{redes} }), 'região Norte');
  is $r->{destaque}{situacao}, 'no_ranking', 'destaque na lista';
  is $r->{destaque}{posicao}, (grep { $_->{codigo_ibge} eq '1100015' } @{ $r->{redes} })[0]{posicao}, 'posição do destaque';

  $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=RO&destaque=3553807')->tx->res->json;
  is $r->{destaque}{situacao}, 'fora_do_recorte', 'município de outra UF';

  $r = $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=SP&destaque=3509502')->tx->res->json;
  is $r->{destaque}{situacao}, 'sem_populacao_idade', 'sem o Censo Demográfico';
  ok !(grep { $_->{codigo_ibge} eq '3509502' } @{ $r->{redes} }), 'e fora da lista';

  my $c = $dbh->selectrow_array(q{SELECT count(*) FROM clean.populacao_municipal WHERE codigo_ibge = '1100015'});
  if ($c) {
    my ($porte) = grep { defined } map { $_->{porte} } grep { $_->{codigo_ibge} eq '1100015' }
      @{ $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=RO')->tx->res->json->{redes} };
    $r = $t->get_ok("/api/ranking/redes?indicador=atendimento_creche&uf=RO&porte=$porte")->status_is(200)->tx->res->json;
    ok((grep { $_->{codigo_ibge} eq '1100015' } @{ $r->{redes} }), 'filtro de porte');
    ok !(grep { ($_->{porte} // '') ne $porte } @{ $r->{redes} }), 'só o porte pedido';
  }
};

subtest 'validações' => sub {
  $t->get_ok('/api/ranking/redes?indicador=atendimento_creche')->status_is(400);
  $t->get_ok('/api/ranking/redes?indicador=atendimento_inexistente&uf=RO')->status_is(400)
    ->json_like('/error' => qr/educação infantil/);
  $t->get_ok('/api/ranking/redes?indicador=atendimento_creche&uf=XW')->status_is(404);
};

done_testing;
