# t/05-tasks/planos_oficiais.t
# #406 (P2-RD-03): medições oficiais dos planos gravadas em lote, sem a
# escola abrir o plano.
#
#   * agenda: próximas 06:00 de America/Sao_Paulo;
#   * só planos VIGENTES não arquivados recebem; encerrado fica congelado,
#     rascunho não entra;
#   * idempotente: rodar de novo não duplica; valor novo da fonte entra;
#   * a task manual roda uma vez e devolve as contagens.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DateTime;
use EduMaps::Task::PlanosOficiais;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $T = 'EduMaps::Task::PlanosOficiais';

{
  my $em = sub { DateTime->new(year => 2026, month => 3, day => 10, hour => $_[0], minute => 0,
                               time_zone => 'America/Sao_Paulo') };
  is $T->can('segundos_ate_proxima')->($em->(5)), 3_600, '05:00 → daqui a 1 h';
  is $T->can('segundos_ate_proxima')->($em->(6)), 86_400, 'às 06:00 → amanhã';
}

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
skip_all('catálogo de indicadores ausente (migration nao aplicada)')
  unless $dbh->selectrow_array("SELECT to_regclass('analytics.escola_indicadores_meta')");

my $INEP = '77777779';
my $limpar = sub {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.ideb_notas_escolas WHERE id_escola = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
END { $limpar->() if $dbh }

$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
  {}, $INEP, "Escola Oficiais $INEP");
my $ideb = $dbh->prepare(q{INSERT INTO clean.ideb_notas_escolas (id_escola, ano, etapa, ideb_observado)
                           VALUES (?, ?, 'fundamental_i', ?)});
$ideb->execute($INEP, 2021, 5.0);
$ideb->execute($INEP, 2023, 5.4);

# metas gravadas direto no banco: nenhuma sincronização por abrir o plano
my $meta = sub ($situacao) {
  my ($p) = $dbh->selectrow_array(q{INSERT INTO clean.planos_gestao (cod_inep, tipo, titulo, situacao)
    VALUES (?, 'acao', ?, ?) RETURNING id}, {}, $INEP, "Plano $situacao", $situacao);
  my ($o) = $dbh->selectrow_array(q{INSERT INTO clean.planos_objetivos (plano_id, titulo, ordem)
    VALUES (?, 'Obj', 1) RETURNING id}, {}, $p);
  my ($m) = $dbh->selectrow_array(q{INSERT INTO clean.planos_metas
    (objetivo_id, descricao, sentido, indicador_codigo, linha_base, linha_base_oficial, alvo)
    VALUES (?, 'IDEB', 'aumentar', 'ideb_ai', 5, 5, 6) RETURNING id}, {}, $o);
  return $m;
};
my %m = map { $_ => $meta->($_) } qw(vigente encerrado rascunho);
my $anos = sub ($mid) {
  $dbh->selectcol_arrayref(q{SELECT ano_ref FROM clean.planos_metas_medicoes
    WHERE meta_id = ? AND origem = 'oficial' ORDER BY ano_ref}, {}, $mid);
};
is $anos->($m{vigente}), [], 'antes: a meta não tem medição';

my $model = $t->app->model('Gestor');
my $r = $model->planos_sincronizar_oficiais;
is $anos->($m{vigente}), [ 2021, 2023 ], 'vigente: os anos da fonte, sem a escola abrir o plano';
is $anos->($m{encerrado}), [], 'encerrado: congelado';
is $anos->($m{rascunho}), [], 'rascunho: não entra';
ok $r->{medicoes} >= 2 && $r->{planos} >= 1, 'contagens do lote';

my $r2 = $model->planos_sincronizar_oficiais;
is $anos->($m{vigente}), [ 2021, 2023 ], 'de novo: não duplica';

$ideb->execute($INEP, 2025, 6.0);
my $job = $t->app->minion->enqueue(planos_oficiais => [{ manual => 1 }] => { queue => "teste_oficiais_$$" });
$t->app->minion->perform_jobs({ queues => ["teste_oficiais_$$"] });
my $info = $t->app->minion->job($job)->info;
is $info->{state}, 'finished', 'task manual terminou';
ok $info->{result}{medicoes} >= 1, 'task devolve as contagens';
is $anos->($m{vigente}), [ 2021, 2023, 2025 ], 'valor novo da fonte entra pela task';
my $sem_reagendar = $t->app->minion->jobs({ tasks => ['planos_oficiais'], queues => ["teste_oficiais_$$"],
                                            states => ['inactive'] })->total;
is $sem_reagendar, 0, 'manual não reagenda';

done_testing;
