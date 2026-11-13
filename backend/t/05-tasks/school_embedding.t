# t/05-tasks/school_embedding.t
# #413: o embedding das escolas (pgvector) se atualiza sozinho e nunca usa 0
# no lugar de nota ausente (#154).
#
#   * agenda: próximas 05:00 de America/Sao_Paulo;
#   * atualizar(): insere a escola nova, atualiza só a que mudou, remove a que
#     saiu das notas e deixa de fora a escola com nota nula;
#   * a task manual roda uma vez, devolve as contagens e não reagenda;
#   * o painel da escola sem notas diz "sem_dado" em vez de cair calado no
#     método antigo.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use DateTime;
use EduMaps::Task::SchoolEmbedding;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $T = 'EduMaps::Task::SchoolEmbedding';

{
  my $em = sub { DateTime->new(year => 2026, month => 3, day => 10, hour => $_[0], minute => 0,
                               time_zone => 'America/Sao_Paulo') };
  is $T->can('segundos_ate_proxima')->($em->(4)), 3_600, '04:00 → daqui a 1 h';
  is $T->can('segundos_ate_proxima')->($em->(5)), 86_400, 'às 05:00 → amanhã';
}

ok !eval { EduMaps::Task::SchoolEmbedding::atualizar(undef, 'x; DROP TABLE y'); 1 }, 'fonte fora do padrão recusada';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
skip_all('analytics.school_embedding ausente (pgvector nao migrado)')
  unless $dbh->selectrow_array("SELECT to_regclass('analytics.school_embedding')");

my $emb = sub ($id) {
  $dbh->selectrow_array('SELECT embedding::text FROM analytics.school_embedding WHERE co_entidade = ?', {}, $id);
};

subtest 'atualizar: insere, atualiza, remove e deixa de fora nota nula' => sub {
  $dbh->begin_work;
  my $ok = eval {
    $dbh->do('CREATE TEMP TABLE notas_teste (co_entidade bigint, '
      . join(', ', map {"$_ numeric"} @EduMaps::Task::SchoolEmbedding::NOTAS) . ') ON COMMIT DROP');
    my $ins = $dbh->prepare('INSERT INTO notas_teste VALUES (?, ?, ?, ?, ?, ?, ?)');
    $ins->execute(90000001, 1, 2, 3, 4, 5, 6);          # nova
    $ins->execute(90000002, 6, 5, 4, 3, 2, 1);          # já existe, mudou
    $ins->execute(90000003, 1, 1, 1, 1, 1, 1);          # já existe, igual
    $ins->execute(90000004, 1, undef, 3, 4, 5, 6);      # nota nula: fora
    # no embedding antes: 2 e 3 (e 4, com um vetor de quando tinha a nota), e
    # 5, que saiu das notas
    my $pre = $dbh->prepare('INSERT INTO analytics.school_embedding VALUES (?, ?::vector)');
    $pre->execute(90000002, '[1,1,1,1,1,1]');
    $pre->execute(90000003, '[1,1,1,1,1,1]');
    $pre->execute(90000004, '[1,0,3,4,5,6]');
    $pre->execute(90000005, '[1,1,1,1,1,1]');

    my ($n0) = $dbh->selectrow_array('SELECT count(*) FROM analytics.school_embedding');
    my $r = EduMaps::Task::SchoolEmbedding::atualizar($dbh, 'pg_temp.notas_teste');
    is $emb->(90000001), '[1,2,3,4,5,6]', 'escola nova entra';
    is $emb->(90000002), '[6,5,4,3,2,1]', 'escola que mudou é atualizada';
    is $emb->(90000003), '[1,1,1,1,1,1]', 'escola igual continua';
    is $emb->(90000004), undef, 'nota nula: fora do embedding (nunca 0)';
    is $emb->(90000005), undef, 'escola que saiu das notas é removida';
    is $r->{inseridas_ou_atualizadas}, 2, 'só grava a nova e a que mudou';
    my ($total) = $dbh->selectrow_array('SELECT count(*) FROM analytics.school_embedding');
    is $total, 3, 'o embedding fica exatamente com as escolas completas da fonte';
    is $r->{removidas}, $n0 - 2, 'removidas: todas as que não estão completas na fonte (a 2 e a 3 ficam)';
    1;
  };
  diag $@ unless $ok;
  $dbh->rollback;
};

subtest 'task manual sobre as notas reais' => sub {
  my $antes = $dbh->selectall_arrayref('SELECT co_entidade, embedding::text FROM analytics.school_embedding ORDER BY 1');
  my $fila = "teste_embedding_$$";
  my $job  = $t->app->minion->enqueue(refresh_school_embeddings => [{ manual => 1 }] => { queue => $fila });
  $t->app->minion->perform_jobs({ queues => [$fila] });
  my $info = $t->app->minion->job($job)->info;
  is $info->{state}, 'finished', 'task manual terminou';
  ok exists $info->{result}{removidas}, 'devolve as contagens';
  my ($fora) = $dbh->selectrow_array(q{
    SELECT count(*) FROM clean.mv_escolas_scores s
    LEFT JOIN analytics.school_embedding e USING (co_entidade)
    WHERE e.co_entidade IS NULL AND } . EduMaps::Task::SchoolEmbedding::_completas('s'));
  is $fora, 0, 'toda escola com as 6 notas tem embedding';
  my $depois = $dbh->selectall_arrayref('SELECT co_entidade, embedding::text FROM analytics.school_embedding ORDER BY 1');
  is scalar(@$depois), scalar(@$antes), 'mesmo número de escolas (fixture já em dia)' if $info->{result}{removidas} == 0;
  my $reag = $t->app->minion->jobs({ tasks => ['refresh_school_embeddings'], queues => [$fila],
                                     states => ['inactive'] })->total;
  is $reag, 0, 'manual não reagenda';
};

subtest 'notas_completas' => sub {
  my ($com) = $dbh->selectrow_array('SELECT co_entidade FROM clean.mv_escolas_scores WHERE '
    . EduMaps::Task::SchoolEmbedding::_completas() . ' LIMIT 1');
  ok EduMaps::Task::SchoolEmbedding::notas_completas($dbh, $com), 'escola com as 6 notas';
  is EduMaps::Task::SchoolEmbedding::notas_completas($dbh, 1), undef, 'escola fora das notas: undef';
};

subtest 'painel: escola sem notas diz sem_dado; com notas, traz vizinhas' => sub {
  my ($com, $muni) = $dbh->selectrow_array(q{
    SELECT e.co_entidade, ce.co_municipio FROM analytics.school_embedding e
    JOIN clean.censo_escolas ce ON ce.co_entidade = e.co_entidade AND ce.tp_situacao_funcionamento = 1
    WHERE (SELECT count(*) FROM analytics.school_embedding e2
           JOIN clean.censo_escolas c2 ON c2.co_entidade = e2.co_entidade AND c2.tp_situacao_funcionamento = 1
           WHERE c2.co_municipio = ce.co_municipio) > 1
    LIMIT 1});
  plan skip_all => 'fixture sem escola com vizinha no município' unless $com;

  $t->get_ok("/api/school/$com/panel/info")->status_is(200)
    ->json_is('/similar_schools_motivo' => undef, 'com notas: sem motivo');
  ok scalar @{ $t->tx->res->json('/similar_schools') // [] }, 'com notas: tem vizinhas';

  my $SEM = 77777781;
  my $ano = $dbh->selectrow_array('SELECT max(nu_ano_censo) FROM clean.censo_escolas');
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $SEM);
  $dbh->do(q{INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade, co_municipio, tp_situacao_funcionamento)
             VALUES (?, ?, 'Escola sem notas', ?, 1)}, {}, $ano, $SEM, $muni);
  # o painel lê a escola com as matrículas (join): sem elas, 404
  $dbh->do('DELETE FROM clean.censo_matriculas WHERE co_entidade = ?', {}, $SEM);
  $dbh->do('INSERT INTO clean.censo_matriculas (nu_ano_censo, co_entidade, qt_mat_bas) VALUES (?, ?, 10)', {}, $ano, $SEM);
  $t->get_ok("/api/school/$SEM/panel/info");
  if ($t->tx->res->code == 200) {
    $t->json_is('/similar_schools' => [], 'sem notas: nenhuma vizinha')
      ->json_is('/similar_schools_motivo' => 'sem_dado', 'sem notas: diz que falta dado');
  }
  else {
    diag 'painel da escola mínima respondeu ' . $t->tx->res->code . ': ' . $t->tx->res->body;
    fail 'painel da escola sem notas';
  }
  $dbh->do("DELETE FROM clean.$_ WHERE co_entidade = ?", {}, $SEM) for qw(censo_matriculas censo_escolas);
};

done_testing;
