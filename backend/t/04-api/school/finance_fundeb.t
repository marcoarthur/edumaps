# t/04-api/school/finance_fundeb.t
# #611 (QE-02 da P2): a folha e o Fundeb no painel da rede. A receita do
# Fundeb vem do DCA (SICONFI, Anexo I-C), anual. Ano com DCA: a parte da
# receita paga pela parcela de 70% e a parte com a adequação ao piso. Ano
# sem DCA: a adequação contra a receita do último ano com DCA.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use EduMaps::Model::School;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

plan skip_all => 'clean.siconfi_receita ausente'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.siconfi_receita')");

my $INEP   = '60061101';   # escola municipal sem folha própria
my $CO_MUN = '6006111';
my $MUN    = '600611';
my $SEC    = 99999999;

sub limpar {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.siconfi_receita WHERE codigo_ibge = ?', {}, $CO_MUN);
  $dbh->do('DELETE FROM clean.malha_municipio WHERE codigo_ibge = ?', {}, $CO_MUN);
}
limpar();
END { limpar() }

my ($ano_censo) = $dbh->selectrow_array('SELECT coalesce(max(nu_ano_censo), 2025) FROM clean.censo_escolas');
$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, tp_situacao_funcionamento)
          VALUES (?, ?, ?, 3, ?, 1)', {}, $ano_censo, $INEP, 'Escola Fundeb', $CO_MUN);
my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, escola, cod_municipio, rede, categoria, tipo, salario_total,
    salario_fundeb_max, salario_fundeb_min, salario_outros)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)');
# 2025: R$ 900 da parcela de 70% e R$ 100 da de 30%, em dois meses
$f->execute(2025, $_, 'ANA', 'xxx.ANA.611-xx', $SEC, 'SEC MUN', $MUN, 'Municipal', 'Docente', 'Profissionais do magistério', 500, 450, 50)
  for qw(Janeiro Fevereiro);
$f->execute(2026, 'Janeiro', 'ANA', 'xxx.ANA.611-xx', $SEC, 'SEC MUN', $MUN, 'Municipal', 'Docente', 'Profissionais do magistério', 500, 450, 50);

$dbh->do('INSERT INTO clean.malha_municipio (codigo_ibge, nome_municipio, sigla_uf) VALUES (?, ?, ?)', {}, $CO_MUN, 'Teste Fundeb', 'XX');
my $r = $dbh->prepare(q{INSERT INTO clean.siconfi_receita
   (codigo_ibge, exercicio, tipo_receita, coluna_receita, descricao_receita, valor, classificacao, dt_snapshot)
   VALUES (?, 2025, 'fundeb', ?, 'x', ?, 'realizada', ?)});
# o snapshot mais recente vale; a complementação soma à receita
$r->execute($CO_MUN, '1.7.5.1.00.0.0', 999, '2026-01-01');
$r->execute($CO_MUN, '1.7.5.1.00.0.0', 1000, '2026-05-01');
$r->execute($CO_MUN, '1.7.1.5.00.0.0', 200, '2026-05-01');

subtest 'ano com DCA: a parte da receita paga pela parcela de 70%' => sub {
  my $j = $t->get_ok("/api/school/$INEP/finance?ano=2025")->status_is(200)->tx->res->json;
  is $j->{origem}, 'rede', 'painel da rede';
  my $x = $j->{fundeb};
  is [ @$x{qw(ano_receita referencia receita complementacao pago_70 parte_70 meses_folha)} ],
     [2025, 0, 1200, 200, 900, 75, 2], 'R$ 900 de R$ 1.200 (75%), em 2 meses de folha';
  like $x->{fonte}, qr/DCA, Anexo I-C/, 'a fonte dita';
};

subtest '#614: o mesmo bloco pelo município' => sub {
  my $x = $t->get_ok("/api/city/$CO_MUN/finance?ano=2025")->status_is(200)->tx->res->json->{fundeb};
  is [ @$x{qw(ano_receita receita pago_70 parte_70)} ], [2025, 1200, 900, 75], 'a parte do Fundeb pelo município';
};

subtest 'ano sem DCA: só a referência do último ano' => sub {
  my $x = $t->get_ok("/api/school/$INEP/finance?ano=2026")->status_is(200)->tx->res->json->{fundeb};
  is [ @$x{qw(ano_receita referencia receita pago_70 parte_70)} ], [2025, 1, 1200, undef, undef],
     'a receita de 2025 como referência, sem a parte paga';
};

subtest 'a adequação ao piso em 13 salários' => sub {
  my $model = EduMaps::Model::School->new(schema => $t->app->schema);
  my $fx = $model->_folha_fundeb($dbh, $MUN, 2025, { fundeb_70 => 900 }, { abaixo_piso_diferenca_mensal => 10 }, 12);
  is [ @$fx{qw(custo_piso_ano parte_custo_piso parte_70_com_piso)} ], [130, 10.8, 85.8], 'R$ 130 no ano: 10,8% da receita, 85,8% com a folha';
  my $ref = $model->_folha_fundeb($dbh, $MUN, 2026, undef, { abaixo_piso_diferenca_mensal => 10 }, 1);
  is [ @$ref{qw(referencia parte_custo_piso parte_70_com_piso)} ], [1, 10.8, undef], 'em 2026, contra a receita de 2025';
};

subtest 'sem o bloco fora do painel da rede ou sem DCA' => sub {
  my $model = EduMaps::Model::School->new(schema => $t->app->schema);
  is $model->_folha_fundeb($dbh, '600612', 2025, undef, undef, 1), undef, 'município sem DCA';
  is $model->_folha_fundeb($dbh, $MUN, 2024, undef, undef, 1), undef, 'só DCA de anos seguintes';
};

done_testing;
