# t/06-tools/ranking_pre_calculado.t
# #467: bin/ranking.pl remove do ranking pré-calculado quem saiu dele (escola
# que ficou sem o índice, fechada ou de outro ano). Antes, o upsert deixava a
# linha antiga, com o 0 da indices-v2, para sempre.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;

my $INEP = '60467001';   # não existe no Censo: a linha só pode ser antiga

my $t = Test::Mojo->new('EduMaps');
my $dbh = $t->app->schema->storage->dbh;

my ($ano) = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.mv_escolas_scores');
plan skip_all => 'MV de índices vazia' unless $ano;

$dbh->do(q{DELETE FROM analytics.ranking_escola WHERE id_escola = ?}, undef, $INEP);
$dbh->do(q{INSERT INTO analytics.ranking_escola (indicador_id, rede, id_escola, ano, valor, data_atualizacao)
           VALUES ('capacitacao_docente', 'todas', ?, ?, 0, now() - interval '1 day')}, undef, $INEP, $ano);

my $saida = qx{$^X -Ilib bin/ranking.pl --source mv 2>&1};
is $? >> 8, 0, 'ranking.pl roda' or diag $saida;

my ($fica) = $dbh->selectrow_array(
  q{SELECT count(*) FROM analytics.ranking_escola WHERE id_escola = ?}, undef, $INEP);
is $fica, 0, 'linha de quem saiu do ranking removida';

my ($sem_indice) = $dbh->selectrow_array(q{
  SELECT count(*) FROM analytics.ranking_escola r
   WHERE r.indicador_id = 'capacitacao_docente'
     AND NOT EXISTS (SELECT 1 FROM clean.mv_escolas_scores s
                      WHERE s.co_entidade = r.id_escola AND s.score_capacitacao_docente IS NOT NULL)});
is $sem_indice, 0, 'escola sem o índice fora do ranking pré-calculado';

my ($n) = $dbh->selectrow_array(
  q{SELECT count(*) FROM analytics.ranking_escola WHERE indicador_id = 'infraestrutura' AND rede = 'todas'});
ok $n > 0, 'o ranking continua preenchido';

$dbh->do(q{DELETE FROM analytics.ranking_escola WHERE id_escola = ?}, undef, $INEP);
done_testing;
