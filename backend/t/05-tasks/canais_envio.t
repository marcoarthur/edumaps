# t/05-tasks/canais_envio.t
# Task Minion `canais_envio [{envio_id}]` (#216, Fase 3): um lote por job;
# lock por envio (sem lock sai); reagenda o próximo lote (60 s) com
# `anterior` e atualiza o minion_job_id; envio desligado → 300 s sem mudar o
# estado; concluído/cancelado → sai sem reagendar. SMTP simulado pelo helper
# `canais_smtp`. Minion no Postgres de teste (perform_jobs).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Task::CanaisEnvio;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
$t->app->helper(canais_smtp => sub { sub { return { ok => 1 } } });

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_envios')")
       && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migrations nao aplicadas' unless $has;

my $app    = $t->app;
my $model  = $app->model('Canal');
my $minion = $app->minion;
my $TASK   = 'canais_envio';
my $INEP   = 99690000 + ($$ % 1000);
my $P      = sprintf '%04d', $$ % 10000;
my ($gid, $lista);

sub limpa_jobs { $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = ?}, $TASK) }
sub limpa {
  limpa_jobs();
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE cod_inep = ? AND referente_tipo = 'envio'},
           {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
             WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.envio.%'
             OR key LIKE 'canais.email.%'});
}
END { limpa() if $has }

sub cfg ($k, $v) { $model->config_put("canais.$k", $v, 'teste') }
sub novo_envio {
  my $e = $model->envio_criar(cod_inep => $INEP, gestor_id => $gid, alvo_tipo => 'lista',
    alvo_id => $lista, operacao => 'aviso', assunto => 'A', corpo => 'B');
  my $r = $model->envio_disparar(cod_inep => $INEP, id => $e->{id}, secret => $app->secrets->[0],
    enqueue => sub ($id, $delay) { $app->canais_envio_enfileirar($id, $delay) });
  return $r;
}
sub job_do ($envio_id) {
  return $dbh->selectrow_array('SELECT minion_job_id FROM clean.canal_envios WHERE id = ?',
                               {}, $envio_id);
}
sub status ($envio_id) {
  return $dbh->selectrow_array('SELECT status FROM clean.canal_envios WHERE id = ?', {}, $envio_id);
}

limpa();
$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
          ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Job');
($gid) = $dbh->selectrow_array(
  'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
  {}, $INEP, 'Gestor Job', "gestor.job.$P\@edumaps.test");
$lista = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'L', coleta => 'email')->{id};
for my $i (1 .. 3) {
  my ($cid) = $dbh->selectrow_array(
    'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email) VALUES (?, ?, ?, ?) RETURNING id',
    {}, $INEP, $gid, "P$i", "job$i.$P\@exemplo.org");
  $dbh->do(q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem)
             VALUES (?, ?, 'manual')}, {}, $lista, $cid);
}
cfg('email.enabled', 'true');
cfg('email.smtp_host', 'smtp.exemplo.org');
cfg('email.from', 'nao-responda@exemplo.org');

subtest 'lotes: reagenda até concluir; cadeia limpa' => sub {
  cfg('envio.ritmo_por_minuto', '2');
  my $e = novo_envio();
  my $j1 = job_do($e->{id});
  ok $j1, 'disparo enfileirou';
  is $minion->job($j1)->info->{args}, [{ envio_id => $e->{id} }], 'args';

  $minion->perform_jobs;
  my $r1 = $minion->job($j1)->info->{result};
  is [ @$r1{qw(reagendar processados)} ], [60, 2], 'lote de 2, reagenda em 60 s';
  my $j2 = job_do($e->{id});
  is $j2, $r1->{proximo}, 'minion_job_id = próximo';
  my $i2 = $minion->job($j2)->info;
  is $i2->{args}, [{ envio_id => $e->{id}, anterior => $j1 }], 'próximo aponta o anterior';
  ok $i2->{delayed} > time + 30, 'atrasado ~60 s';
  is status($e->{id}), 'enviando', 'enviando';

  $minion->job($j2)->retry({ delay => 0 });
  $minion->perform_jobs;
  is $minion->job($j2)->info->{result}, { fim => 'concluido', processados => 1 }, 'concluído';
  ok !$minion->job($j1), 'job anterior removido';
  is status($e->{id}), 'concluido', 'status final';
  ok !$minion->is_locked("$TASK:$e->{id}"), 'lock solto';
  is $minion->jobs({ tasks => [$TASK], states => ['inactive'] })->total, 0, 'nada pendente';
  cfg('envio.ritmo_por_minuto', '60');
};

subtest 'lock: outro lote em curso → sai' => sub {
  limpa_jobs();
  $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $INEP);
  my $e = novo_envio();
  ok $minion->lock("$TASK:$e->{id}", 60), 'lock tomado';
  my $j = job_do($e->{id});
  $minion->perform_jobs;
  is $minion->job($j)->info->{result}, { parado => 'lock' }, 'parado';
  is status($e->{id}), 'enviando', 'nada processado';
  $minion->unlock("$TASK:$e->{id}");
};

subtest 'desligado: reagenda em 300 s sem mudar o estado; cancelado sai' => sub {
  limpa_jobs();
  my ($e) = $dbh->selectrow_array(
    q{SELECT id FROM clean.canal_envios WHERE cod_inep = ? AND status = 'enviando'}, {}, $INEP);
  cfg('envio.enabled', 'false');
  my $j = $app->canais_envio_enfileirar($e);
  $minion->perform_jobs;
  my $r = $minion->job($j)->info->{result};
  is [ @$r{qw(reagendar motivo)} ], [300, 'envio_desligado'], 'reagenda em 300 s';
  ok $minion->job($r->{proximo})->info->{delayed} > time + 250, 'atrasado';
  is status($e), 'enviando', 'estado inalterado';
  cfg('envio.enabled', 'true');

  $model->envio_cancelar($INEP, $e);
  $minion->job($r->{proximo})->retry({ delay => 0 });
  $minion->perform_jobs;
  is $minion->job($r->{proximo})->info->{result}, { fim => 'cancelado' }, 'cancelado: sai';
  is $minion->jobs({ tasks => [$TASK], states => ['inactive'] })->total, 0, 'sem reagendar';

  my $s = $minion->enqueue($TASK => [{}]);
  $minion->perform_jobs;
  is $minion->job($s)->info->{result}, { parado => 'sem_envio' }, 'args inválidos';
};

done_testing;
