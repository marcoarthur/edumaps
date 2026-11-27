# t/04-api/school/finance_secretaria.t
# Painel financeiro: quando a escola não tem folha própria, o SIOPE pode ter
# declarado o agregado do município (cod_inep 99999999 / "SEC MUN DE EDUC ...").
# Nesse caso o resumo cai para o agregado do município e sinaliza a origem.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.remuneracao_municipal')"
);

# Escola municipal SEM folha própria; município tem o agregado 99999999.
my $INEP = '77777730';
my $CO_MUN = '7777773';
my $MUN    = '777777';

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep IN (?, 99999999) AND cod_municipio::text = ?', {}, $INEP, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
            VALUES (2025, ?, ?, 3, ?)', {}, $INEP, 'Escola Sem Folha', $CO_MUN);
  # agregado da secretaria (99999999) para o município
  for my $m (qw(Janeiro Fevereiro)) {
    $dbh->do('INSERT INTO clean.remuneracao_municipal
                (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total,
                 salario_fundeb_max, salario_fundeb_min, salario_outros)
              VALUES (2024, ?, ?, ?, 99999999, ?, ?, ?, ?, 1000, 700, 200, 100)',
      {}, $m, "Servidor $m", "xxx.$m.025-xx", $MUN, 'Municipal',
      'Docente habilitado em curso de pedagogia', 'Profissionais do magistério');
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_inep = 99999999 AND cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
}

subtest 'escola sem folha própria cai para o agregado da Secretaria' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente (migration nao aplicada)'
    unless $has_tables;

  my $r = $t->get_ok("/api/school/$INEP/finance")
    ->status_is(200)->tx->res->json;

  is $r->{origem}, 'rede', 'origem: o painel da rede municipal (#610)';
  like $r->{rotulo_origem} // '', qr/rede municipal/i, 'rótulo de origem presente';
  is [ @{ $r->{rede} }{qw(declaracao escolas_com_folha)}, $r->{rede}{partes} ],
     ['secretaria', 0, { escolas => 0, secretaria => 2000, fora => 0 }], '#610: só no total da Secretaria';
  is scalar(@{ $r->{series} }), 2, 'série vem do agregado (2 competências)';
  ok $r->{total_profissionais} >= 2, 'total de profissionais do agregado';
  # #553 (QS-01 da P5): a folha do agregado por fonte de recurso
  is($r->{por_fonte}, { fundeb_70 => 1400, fundeb_30 => 400, outras => 200, total => 2000, nao_informado => 0 },
    'folha por fonte: Fundeb 70%, 30% e outras, somando o total');
};

subtest 'folha detalhada do total da Secretaria (#585)' => sub {
  plan skip_all => 'clean.remuneracao_municipal ausente' unless $has_tables;
  my $r = $t->get_ok("/api/school/$INEP/payroll/secretaria?date=01-2024")->status_is(200)->tx->res->json;
  is scalar(@$r), 1, 'janeiro: uma pessoa no total da Secretaria';
  is $r->[0]{nome_profissional}, 'Servidor Janeiro', 'com o nome';
  is $r->[0]{salario_total}, 1000, 'e o salário';
  $t->get_ok("/api/school/$INEP/payroll/secretaria?date=05-2024")->status_is(404);
  $t->get_ok("/api/school/$INEP/payroll/secretaria?date=xx")->status_is(400);
};

done_testing;
