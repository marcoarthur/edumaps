# t/05-tasks/clustering_etapa.t
# #481 (RO-01): a tabela de indicadores do agrupamento traz o IDEB/SAEB da
# etapa escolhida, não a média entre as etapas da escola. Roda o SQL do job
# numa tabela temporária (a clean.school_indicators é de todos os jobs).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use EduMaps::Task::Clustering;
use EduMaps::Presets;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;

my $INEP = '60481001';
my $limpa = sub {
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola = ?', undef, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', undef, $INEP);
};
$limpa->();
$dbh->do(q{INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, tp_situacao_funcionamento,
             co_municipio, no_municipio, sg_uf, no_uf, co_regiao, no_regiao)
           VALUES (2025, ?, 'Escola Duas Etapas', 3, 1, 1199998, 'Teste', 'RO', 'Rondônia', 1, 'Norte')}, {}, $INEP);
$dbh->do(q{INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, rede, ano, etapa, nota_matematica, ideb_observado)
           VALUES (?, 'RO', 1199998, 'Municipal', 2023, 'fundamental_i', 220, 6.0),
                  (?, 'RO', 1199998, 'Municipal', 2023, 'fundamental_ii', 250, 4.0)}, {}, $INEP, $INEP);

my $sql = EduMaps::Task::Clustering::_indicators_build_sql();
like $sql, qr/etapa = \?/, 'o SQL filtra a etapa';
(my $tmp = $sql) =~ s/INSERT INTO clean\.school_indicators/INSERT INTO pg_temp.si/;
$dbh->do('CREATE TEMP TABLE si (LIKE clean.school_indicators)');

my $le = sub ($cod) {
  $dbh->do('TRUNCATE pg_temp.si');
  $dbh->do($tmp, undef, 2023, $cod, $cod);
  return $dbh->selectrow_hashref('SELECT nota_matematica::float8 AS mat, ideb_observado::float8 AS ideb FROM pg_temp.si WHERE co_entidade = ?', undef, $INEP);
};
is $le->(EduMaps::Presets->etapa('anos_iniciais')->{etapa}), { mat => 220, ideb => 6 }, 'anos iniciais: só a nota dos anos iniciais';
is $le->(EduMaps::Presets->etapa('anos_finais')->{etapa}),   { mat => 250, ideb => 4 }, 'anos finais: só a dos anos finais';
is $le->(EduMaps::Presets->etapa('ensino_medio')->{etapa}),  { mat => undef, ideb => undef }, 'ensino médio: sem nota, fica vazia';
is $le->(undef), { mat => 235, ideb => 5 }, 'sem etapa (agrupamento sem IDEB): a média, que não é usada';

ok( EduMaps::Presets->usa_ideb(['prop_mestrado', 'nota_media']), 'lista com coluna do IDEB');
ok( !EduMaps::Presets->usa_ideb(EduMaps::Presets->get('infraestrutura')->{features}), 'infraestrutura sem IDEB');

$limpa->();
done_testing;
