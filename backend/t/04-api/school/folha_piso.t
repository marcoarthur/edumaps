# t/04-api/school/folha_piso.t
# #598 (QB-02 da P2): na lista da folha (da escola e do total da Secretaria),
# cada pessoa do magistério traz a base por 40 h no ano e a marca "abaixo do
# piso no ano", com a regra da contagem da rede: a mediana dos meses em toda
# a folha do município (escolas e Secretaria), sem dezembro, 3 meses ou mais.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

plan skip_all => 'clean.remuneracao_municipal ausente'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.remuneracao_municipal')");

my $INEP   = '60059801';
my $CO_MUN = '6005981';
my $MUN    = '600598';
my $ANO    = 2026;
my $MAG    = 'Profissionais do magistério';

sub limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
}
limpar();
END { limpar(); $dbh->do('SELECT analytics.refresh_salario_rede()') if $dbh }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
          VALUES (2025, ?, ?, 3, ?)', {}, $INEP, 'Escola do Piso', $CO_MUN);
my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, situacao, carga_horaria, salario_base, salario_total)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
my @l = (
  # ANA: na escola, 4.000 por 40 h nos três meses: abaixo
  (map { ['ANA', $_, $INEP, $MAG, 'Efetivo', 40, 4000] } qw(Janeiro Fevereiro Março)),
  # BIA: janeiro na Secretaria, fevereiro e março na escola: 3 meses na rede, abaixo
  ['BIA', 'Janeiro', 99999999, $MAG, 'Temporário', 40, 3000],
  (map { ['BIA', $_, $INEP, $MAG, 'Temporário', 40, 3000] } qw(Fevereiro Março)),
  # CAIO: na Secretaria, 3.000 por 20 h = 6.000 por 40 h: acima
  (map { ['CAIO', $_, 99999999, $MAG, 'Temporário', 20, 3000] } qw(Janeiro Fevereiro Março)),
  # DUDA: só março na Secretaria (avulso): não conta
  ['DUDA', 'Março', 99999999, $MAG, 'Outros', 40, 1000],
  # EVA: não é do magistério: sem a conta
  (map { ['EVA', $_, $INEP, 'Outros profissionais da educação', 'Efetivo', 40, 1500] } qw(Janeiro Fevereiro Março)),
);
$f->execute($ANO, $_->[1], $_->[0], "xxx.$_->[0].598-xx", $_->[2], $MUN, 'Municipal', 'Docente', $_->[3], $_->[4], $_->[5], $_->[6], $_->[6])
  for @l;
# 2001 não tem piso cadastrado
$f->execute(2001, 'Janeiro', 'ANA', 'xxx.ANA.598-xx', $INEP, $MUN, 'Municipal', 'Docente', $MAG, 'Efetivo', 40, 100, 100);
$dbh->do('SELECT analytics.refresh_salario_rede()');

sub por_nome ($rows) { return { map { ($_->{nome_profissional} => $_) } @$rows } }

subtest 'folha da escola' => sub {
  my $r = por_nome($t->get_ok("/api/school/$INEP/payroll?date=03-$ANO")->status_is(200)->tx->res->json);
  is [ $r->{ANA}{base_40h_ano}, !!$r->{ANA}{abaixo_piso_ano} ], [4000, 1], 'ANA abaixo, com a base por 40 h';
  is [ $r->{BIA}{base_40h_ano}, !!$r->{BIA}{abaixo_piso_ano} ], [3000, 1],
    'BIA abaixo: conta o mês da Secretaria (a regra é a da rede inteira)';
  is [ $r->{EVA}{base_40h_ano}, $r->{EVA}{abaixo_piso_ano} ], [undef, undef], 'fora do magistério: sem a conta';
};

subtest 'folha do total da Secretaria' => sub {
  my $jan = por_nome($t->get_ok("/api/school/$INEP/payroll/secretaria?date=01-$ANO")->status_is(200)->tx->res->json);
  ok $jan->{BIA}{abaixo_piso_ano}, 'BIA marcada na Secretaria, com um mês só ali';
  is [ $jan->{CAIO}{base_40h_ano}, !!$jan->{CAIO}{abaixo_piso_ano} ], [6000, ''], 'CAIO: 20 h convertidas, acima';
  my $mar = por_nome($t->get_ok("/api/school/$INEP/payroll/secretaria?date=03-$ANO")->status_is(200)->tx->res->json);
  is [ $mar->{DUDA}{base_40h_ano}, !!$mar->{DUDA}{abaixo_piso_ano} ], [1000, ''], 'DUDA: menos de 3 meses, não marcada';
};

subtest 'ano sem piso: sem a marca' => sub {
  my $r = por_nome($t->get_ok("/api/school/$INEP/payroll?date=01-2001")->status_is(200)->tx->res->json);
  is [ $r->{ANA}{base_40h_ano}, $r->{ANA}{abaixo_piso_ano} ], [undef, undef], 'vazios, não falso';
};

done_testing;
