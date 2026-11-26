# t/04-api/city_piso_lista.t
# #601 (QC-01 da P2): a lista do ano de quem fica abaixo do piso na rede
# municipal, uma linha por pessoa, com a regra da contagem do painel
# (salario_rede): toda a folha do município, sem dezembro, 3 meses ou mais.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::BaseAnalise ();

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

plan skip_all => 'clean.remuneracao_municipal ausente'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.remuneracao_municipal')");

my $INEP   = '60060101';
my $CO_MUN = '6006011';
my $MUN    = '600601';
my $ANO    = 2026;
my $MAG    = 'Profissionais do magistério';

sub limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
}
limpar();
END { limpar(); $dbh->do('SELECT analytics.refresh_salario_rede()') if $dbh }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf)
          VALUES (2025, ?, ?, 3, ?, ?, ?)', {}, $INEP, 'Escola da Lista', $CO_MUN, 'Município da Lista', 'AC');
my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, escola, cod_municipio, rede, categoria, tipo, situacao, carga_horaria, salario_base, salario_total)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
my $SEC = 99999999;
my @l = (
  # ANA: na escola, 30 h com base de 3.000 (4.000 por 40 h): abaixo; temporária em 2 de 3 meses
  ['ANA', 'Janeiro', $INEP, 'Efetivo', 30, 3000], ['ANA', 'Fevereiro', $INEP, 'Temporário', 30, 3000],
  ['ANA', 'Março', $INEP, 'Temporário', 30, 3000],
  # BIA: janeiro na Secretaria, fevereiro e março na escola: abaixo, nos dois lugares
  ['BIA', 'Janeiro', $SEC, 'Efetivo', 40, 3500], ['BIA', 'Fevereiro', $INEP, 'Efetivo', 40, 3500],
  ['BIA', 'Março', $INEP, 'Efetivo', 40, 3500],
  # CAIO: acima (6.000 por 40 h); DUDA: só um mês; dezembro de ANA não conta
  (map { ['CAIO', $_, $SEC, 'Efetivo', 20, 3000] } qw(Janeiro Fevereiro Março)),
  ['DUDA', 'Março', $SEC, 'Outros', 40, 1000],
  ['ANA', 'Dezembro', $INEP, 'Efetivo', 30, 100],
);
$f->execute($ANO, $_->[1], $_->[0], "xxx.$_->[0].601-xx", $_->[2], ($_->[2] == $SEC ? 'SEC MUN' : 'ESCOLA DA LISTA'),
  $MUN, 'Municipal', 'Docente', $MAG, $_->[3], $_->[4], $_->[5], $_->[5]) for @l;
$dbh->do('SELECT analytics.refresh_salario_rede()');

subtest 'lista em JSON' => sub {
  my $r = $t->get_ok("/api/city/$CO_MUN/piso?ano=$ANO")->status_is(200)->tx->res->json;
  is [ @$r{qw(codigo_ibge municipio uf ano piso total)} ], [$CO_MUN, 'Município da Lista', 'AC', $ANO, 5130.63, 2], 'cabeçalho';
  is [ map { $_->{nome} } @{ $r->{pessoas} } ], [qw(ANA BIA)], 'ANA e BIA, em ordem de nome (CAIO acima, DUDA com um mês)';
  my ($ana, $bia) = @{ $r->{pessoas} };
  is [ @$ana{qw(cpf_mascarado situacao carga_comum base_mensal_mediana base_40h meses)} ],
     ['xxx.ANA.601-xx', 'temporario', 30, 3000, 4000, 3], 'ANA: situação dos mais meses, sem dezembro';
  is [ !!$ana->{secretaria}, $ana->{inep_escolas} ], ['', [$INEP]], 'ANA só na escola';
  is [ !!$bia->{secretaria}, $bia->{inep_escolas}, $bia->{escolas} ], [1, [$INEP], ['ESCOLA DA LISTA']], 'BIA na Secretaria e na escola';
  ok !grep({ exists $_->{cpf} } @{ $r->{pessoas} }), 'só o CPF mascarado, com esse nome';
  my $s = EduMaps::BaseAnalise->salario_rede($dbh, $MUN)->{"$MUN|$ANO"};
  is $r->{total}, $s->{abaixo_piso}, 'o mesmo total da contagem do painel';
  ok scalar(@{ $r->{colunas} }) >= 10, 'as colunas descritas';
};

subtest 'CSV' => sub {
  my $tx = $t->get_ok("/api/city/$CO_MUN/piso?ano=$ANO&formato=csv")->status_is(200)
    ->header_like('Content-Disposition' => qr/abaixo-piso-$CO_MUN-$ANO\.csv/)->tx;
  my @l = split /\r?\n/, $tx->res->text;
  like $l[0], qr/^\x{FEFF}?nome;cpf_mascarado;situacao;carga_comum;base_mensal_mediana;base_40h;piso_ano;meses;secretaria;inep_escolas;escolas$/, 'cabeçalho';
  is scalar(@l), 3, 'duas pessoas';
  like $l[2], qr/^BIA;xxx\.BIA\.601-xx;efetivo;40;3500;3500;5130,63;3;sim;$INEP;ESCOLA DA LISTA$/, 'linha de BIA';
};

subtest 'sem a conta' => sub {
  $t->get_ok("/api/city/$CO_MUN/piso?ano=2001")->status_is(404)->json_like('/error' => qr/Sem piso/);
  $t->get_ok("/api/city/6999999/piso")->status_is(404);
  $t->get_ok("/api/city/$CO_MUN/piso?ano=xx")->status_is(400);
  my $r = $t->get_ok("/api/city/$CO_MUN/piso")->status_is(200)->tx->res->json;
  is $r->{ano}, $ANO, 'sem ano: o último com folha';
};

done_testing;
