# t/04-api/school/finance_docentes.t
# #567 (P1-FL-01 da P1): o painel financeiro mostra os docentes do Censo ao
# lado da folha e avisa quando muitos profissionais do magistério do
# município estão só no total da Secretaria (B1: 10% ou mais).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use EduMaps::BaseAnalise;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $INEP   = '60056701';   # municipal, com folha
my $CO_MUN = 6005670;
my $MUN    = '600567';
my $MAG    = 'Profissionais do magistério';

my $limpa = sub {
  $dbh->do('DELETE FROM clean.remuneracao_municipal WHERE cod_municipio::text = ?', {}, $MUN);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_docentes WHERE co_entidade = ?', {}, $INEP);
};
$limpa->();
END { $limpa->() if $dbh }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio)
          VALUES (2025, ?, ?, 3, ?)', {}, $INEP, 'Escola Docentes', $CO_MUN);
$dbh->do('INSERT INTO clean.censo_docentes (nu_ano_censo, co_entidade, qt_doc_bas) VALUES (2025, ?, 10)', {}, $INEP);

my $f = $dbh->prepare('INSERT INTO clean.remuneracao_municipal
   (ano, mes, nome_profissional, cpf, cod_inep, cod_municipio, rede, categoria, tipo, salario_total)
   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1000)');
# 2001: ANA nos dois meses e BIA só em janeiro, na escola; CAIO só na Secretaria
$f->execute(2001, $_->[0], $_->[1], "xxx.$_->[1].567-xx", $_->[2], $MUN, 'Municipal', 'Docente', $MAG)
  for ['Janeiro', 'ANA', $INEP], ['Fevereiro', 'ANA', $INEP], ['Janeiro', 'BIA', $INEP], ['Janeiro', 'CAIO', 99999999];
# 2002: só a escola (ninguém só na Secretaria)
$f->execute(2002, 'Janeiro', 'ANA', 'xxx.ANA.567-xx', $INEP, $MUN, 'Municipal', 'Docente', $MAG);

my $r = $t->get_ok("/api/school/$INEP/finance?ano=2001")->status_is(200)->tx->res->json;
my $d = $r->{docentes};
is [ @$d{qw(folha_ano folha_por_mes)} ], [2, 1.5], 'folha: 2 pessoas no ano, 1,5 por mês';
is $d->{censo}, { docentes => 10, ano => 2025 }, 'Censo: 10 docentes em 2025';
is [ @{ $d->{municipio} }{qw(magisterio so_secretaria)} ], [3, 1], 'município: 3 no magistério, 1 só na Secretaria';
ok $d->{municipio}{avisar}, 'um terço só na Secretaria: avisa';

$r = $t->get_ok("/api/school/$INEP/finance?ano=2002")->tx->res->json;
ok !$r->{docentes}{municipio}{avisar}, 'ninguém só na Secretaria: sem aviso';

# #571 (QI-01 da P3): o salário do magistério da rede inteira, com a Secretaria
$dbh->do(q{UPDATE clean.remuneracao_municipal SET salario_base = 600, carga_horaria = 30 WHERE cod_municipio::text = ?}, {}, $MUN);
$f->execute(2001, 'Dezembro', 'ANA', 'xxx.ANA.567-xx', $INEP, $MUN, 'Municipal', 'Docente', $MAG);   # 13º: fora
$r = $t->get_ok("/api/school/$INEP/finance?ano=2001")->tx->res->json;
is $r->{salario_rede}, { pessoas => 3, total => 1000, base => 600, carga_comum => 30 },
  'rede inteira: 3 pessoas (escola e Secretaria), sem dezembro';
my ($c) = grep { $_->{codigo_ibge} eq "$CO_MUN" } @{ EduMaps::BaseAnalise->cobertura_siope($dbh) };
my ($a1) = grep { $_->{ano} == 2001 } @{ $c->{anos} };
is $a1->{salario_magisterio}{pessoas}, 3, 'na cobertura da folha também';

done_testing;
