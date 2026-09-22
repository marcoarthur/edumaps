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
                (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total)
              VALUES (2024, ?, ?, ?, 99999999, ?, ?, ?, ?, 1000)',
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

  is $r->{origem}, 'secretaria', 'origem sinaliza o agregado do município';
  like $r->{rotulo_origem} // '', qr/Secretaria/i, 'rótulo de origem presente';
  is scalar(@{ $r->{series} }), 2, 'série vem do agregado (2 competências)';
  ok $r->{total_profissionais} >= 2, 'total de profissionais do agregado';
};

done_testing;
