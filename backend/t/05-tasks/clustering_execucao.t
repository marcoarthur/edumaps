# t/05-tasks/clustering_execucao.t
# #427: o agrupamento da tela (tabela de indicadores, motor http) vira uma
# execução guardada: o job cria o registro com recorte, parâmetros e as
# escolas que não funcionam mais; o R grava as atribuições e completa o
# universo; o resultado do job traz o run_id.
use strictures 2;
use lib qw(./lib t/lib);
use Test::Mojo;
use Imports;
use CI;
use Utils qw(run_clustering_job cleanup_job);
use EduMaps::Presets;

CI->skip_r('clustering executado no R');
my $t = Test::Mojo->new('EduMaps');
CI->skip_analytics($t->app, 'clustering executado no R');

my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'analytics.cluster_execucoes ausente'
  unless $dbh->selectrow_array(q{SELECT to_regclass('analytics.cluster_execucoes') IS NOT NULL});

# Município do banco com mais escolas (Vitória no dev; o que houver no CI).
my ($mun) = $dbh->selectrow_array(q{
  SELECT co_municipio FROM clean.censo_escolas
   WHERE tp_situacao_funcionamento = 1
   GROUP BY co_municipio ORDER BY count(*) DESC LIMIT 1});
my $preset = EduMaps::Presets->get('infraestrutura');

my $job = run_clustering_job($t, {
  schema     => 'clean',
  table_name => EduMaps::Presets->INDICATORS_TABLE,
  id_column  => 'co_entidade',
  preset_id  => 'infraestrutura',
  features   => $preset->{features},
  algorithm  => 'kmeans',
  clusters   => 3,
  filter     => { co_municipio => 0 + $mun },
});

is $job->info->{state}, 'finished', 'job terminou' or diag explain $job->info->{result};
my $run_id = $job->info->{result}{meta}{run_id};
like $run_id, qr/^run_\d+_[0-9a-f]{8}$/, 'resultado traz o run_id';

my $exec = $t->app->model('Cluster')->execucao($run_id);
ok $exec, 'execução guardada';
is $exec->{estado}, 'concluida', 'estado concluída';
is $exec->{recorte}{codigo_ibge}, "$mun", 'recorte = município';
is $exec->{parametros}{clusters}, 3, 'k guardado';
is $exec->{parametros}{preset}, 'infraestrutura', 'preset guardado';

my $u = $exec->{universo};
my ($total, $inativas) = $dbh->selectrow_array(q{
  SELECT count(*), count(*) FILTER (WHERE tp_situacao_funcionamento IS DISTINCT FROM 1)
    FROM clean.school_indicators WHERE co_municipio = ?}, {}, $mun);
is $u->{n_total}, $total, 'total do recorte';
is $u->{n_inativas}, $inativas, 'que não funcionam mais';
is $u->{n_recorte}, $total - $inativas, 'o R recebeu só as que funcionam';
is $u->{n_agrupadas}, $u->{n_recorte} - $u->{n_incompletas}, 'agrupadas = recorte - incompletas';
is $exec->{n_atribuicoes}, $u->{n_agrupadas}, 'uma atribuição por escola agrupada';
is scalar @{ $exec->{resumo} }, 3, 'resumo da própria execução (3 grupos)';

my ($valores) = $dbh->selectrow_array(
  'SELECT valores::text FROM analytics.cluster_atribuicoes WHERE run_id = ? LIMIT 1', {}, $run_id);
like $valores, qr/in_agua_potavel/, 'valores dos indicadores guardados';

$dbh->do('DELETE FROM analytics.cluster_execucoes WHERE run_id = ?', {}, $run_id);
$dbh->do('DELETE FROM analytics.clustering_metadata WHERE run_id = ?', {}, $run_id);
cleanup_job($t, $job);

done_testing;
