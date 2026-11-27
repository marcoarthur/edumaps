# t/04-api/school/finance_rede.t
# #610 (QE-01 da P2): o painel da rede (escola municipal sem folha própria)
# soma toda a folha do município: escolas da lista do Censo, o total da
# Secretaria e escolas que o Censo não lista; diz a parte de cada uma e como
# o município declarou no ano. A folha detalhada da rede lista o mês inteiro.
# Em Cuiabá 2025 o painel dizia R$ 17,1 mi (só a Secretaria) de R$ 489,5 mi.
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

my $INEP_SEM = '60061001';   # escola municipal sem folha própria
my $INEP_COM = '60061002';   # escola com folha (na lista do Censo)
my $INEP_FORA = '60061003';  # escola na folha, fora da lista do Censo
my $CO_MUN = '6006101';
my $MUN    = '600610';
my $SEC    = 99999999;

sub limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade IN (?, ?)', {}, $INEP_SEM, $INEP_COM);
}
limpar();
END { limpar() }

my ($ano_censo) = $dbh->selectrow_array('SELECT coalesce(max(nu_ano_censo), 2025) FROM clean.censo_escolas');
$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, tp_situacao_funcionamento)
          VALUES (?, ?, ?, 3, ?, 1)', {}, $ano_censo, $_->[0], $_->[1], $CO_MUN)
  for [$INEP_SEM, 'Escola Sem Folha'], [$INEP_COM, 'Escola Com Folha'];
my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, escola, cod_municipio, rede, categoria, tipo, salario_total,
    salario_fundeb_max, salario_fundeb_min, salario_outros)
   VALUES (2026, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0)');
# janeiro por escola (a da lista e uma fora dela); fevereiro na Secretaria
$f->execute('Janeiro', 'ANA', 'xxx.ANA.610-xx', $INEP_COM, 'ESCOLA COM FOLHA', $MUN, 'Municipal', 'Docente', 'Profissionais do magistério', 3000, 3000);
$f->execute('Janeiro', 'BIA', 'xxx.BIA.610-xx', $INEP_FORA, 'ESCOLA FORA', $MUN, 'Municipal', 'Docente', 'Profissionais do magistério', 1000, 1000);
$f->execute('Fevereiro', $_, "xxx.$_.610-xx", $SEC, 'SEC MUN', $MUN, 'Municipal', 'Docente', 'Profissionais do magistério', 2000, 2000)
  for qw(ANA BIA CAIO);

subtest 'o painel da rede inteira' => sub {
  my $r = $t->get_ok("/api/school/$INEP_SEM/finance?ano=2026")->status_is(200)->tx->res->json;
  is $r->{origem}, 'rede', 'origem: a rede municipal';
  is [ map { [ $_->{mes_num}, $_->{total_salario}, $_->{total_secretaria}, $_->{total_profissionais} ] } @{ $r->{series} } ],
     [[1, 4000, 0, 2], [2, 6000, 6000, 3]], 'janeiro das escolas e fevereiro da Secretaria, com a parte da Secretaria';
  is $r->{total_profissionais}, 3, 'as pessoas da rede no ano';
  is $r->{por_fonte}{total}, 10000, 'a fonte da folha inteira';
  is $r->{rede}{partes}, { escolas => 3000, secretaria => 6000, fora => 1000 }, 'as três partes do total';
  is [ @{ $r->{rede} }{qw(declaracao escolas_com_folha meses_escola meses_secretaria)} ],
     ['misto', 2, [1], [2]], 'declarou por escola em janeiro e na Secretaria em fevereiro';
};

subtest 'a escola com folha própria segue com a dela' => sub {
  my $r = $t->get_ok("/api/school/$INEP_COM/finance?ano=2026")->status_is(200)->tx->res->json;
  is [ $r->{origem}, $r->{rede}, scalar @{ $r->{series} } ], ['escola', undef, 1], 'só janeiro, sem o bloco da rede';
};

subtest 'a folha detalhada da rede no mês' => sub {
  my $jan = $t->get_ok("/api/school/$INEP_SEM/payroll/rede?date=01-2026")->status_is(200)->tx->res->json;
  is [ sort map { "$_->{nome_profissional}|$_->{cod_inep}" } @$jan ], ["ANA|$INEP_COM", "BIA|$INEP_FORA"], 'janeiro: as duas escolas';
  my $fev = $t->get_ok("/api/school/$INEP_SEM/payroll/rede?date=02-2026")->status_is(200)->tx->res->json;
  is scalar(@$fev), 3, 'fevereiro: os três na Secretaria';
  $t->get_ok("/api/school/$INEP_SEM/payroll/rede?date=05-2026")->status_is(404);
  $t->get_ok("/api/school/$INEP_SEM/payroll/rede?date=xx")->status_is(400);
};

done_testing;
