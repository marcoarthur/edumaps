# t/05-tasks/canais_retencao.t
# Task Minion `canais_retencao` (#214, RF-207): diária e autorreagendável;
# parada com a config desligada; `{manual:1}` executa uma vez sem reagendar
# (mesmo desligada); lock único (manual sem lock para; diária sem lock
# adia); `agendado` ignora jobs manuais; início no boot do worker (enabled,
# atrasado) e pelo helper. Minion no Postgres de teste (perform_jobs).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

use EduMaps::Task::CanaisRetencao;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')")
  && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migrations nao aplicadas' unless $has;

my $app    = $t->app;
my $model  = $app->model('Canal');
my $minion = $app->minion;
my $TASK   = 'canais_retencao';
my ($ex_max) = $dbh->selectrow_array('SELECT COALESCE(max(id), 0) FROM clean.canal_exclusoes');

sub limpa_jobs { $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = ?}, $TASK) }
sub limpa {
  limpa_jobs();
  $minion->unlock($TASK);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.retencao.%'});
  $dbh->do(q{DELETE FROM clean.canal_exclusoes WHERE origem = 'retencao' AND id > ?}, {}, $ex_max);
}
END { limpa() }

sub jobs ($states) {
  my @out;
  my $it = $minion->jobs({ tasks => [$TASK], states => $states });
  while (my $j = $it->next) { push @out, $j }
  return \@out;
}
sub resumo_novo {
  return $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_exclusoes
      WHERE origem = 'retencao' AND cod_inep = 0 AND id > ?}, {}, $ex_max) + 0;
}
sub desliga { $model->config_put('canais.retencao.enabled', 'false', 't') }
sub liga    { $model->config_put('canais.retencao.enabled', 'true', 't') }

limpa();

subtest 'diária: executa e reagenda para daqui a 24h' => sub {
  liga();
  my $r = $app->canais_retencao_start;
  ok $r->{job_id}, 'enfileirada';
  is $app->canais_retencao_start->{ja_ativo}, 1, 'segunda chamada: já ativa';
  ok $app->canais_retencao_agendado, 'agendado';

  $minion->perform_jobs;
  my $res = $minion->job($r->{job_id})->info->{result};
  ok $res->{resultado}{metadados} && $res->{resultado}{pendentes} && $res->{resultado}{lista_inativa},
    'três regras executadas';
  is resumo_novo(), 3, 'três linhas de resumo';
  ok $res->{proximo}, 'próximo job';
  my $prox = $minion->job($res->{proximo})->info;
  is $prox->{state}, 'inactive', 'próximo pendente';
  ok $prox->{delayed} > time + 86_000, 'atrasado ~24h';
  is $prox->{args}, [{ anterior => $r->{job_id} }], 'aponta o anterior';
  ok !$minion->is_locked($TASK), 'lock solto';
  ok $app->canais_retencao_agendado, 'continua agendado';

  # o próximo da cadeia remove o anterior (finished)
  $minion->job($res->{proximo})->retry({ delay => 0 });
  $minion->perform_jobs;
  ok !$minion->job($r->{job_id}), 'job anterior removido';
  is resumo_novo(), 6, 'segunda execução registrada (mesmo com zero)';
};

subtest 'desligada: o job diário para sem reagendar' => sub {
  limpa_jobs(); desliga();
  my $id = $minion->enqueue($TASK => [{}]);
  $minion->perform_jobs;
  is $minion->job($id)->info->{result}, { parado => 'desligado' }, 'parado';
  is scalar @{ jobs([qw(inactive active)]) }, 0, 'sem reagendamento';
  ok !$app->canais_retencao_agendado, 'não agendado';
};

subtest 'manual: uma vez, sem reagendar, mesmo desligada' => sub {
  limpa_jobs(); desliga();
  my $antes = resumo_novo();
  my $id = $app->canais_retencao_executar;
  ok !$app->canais_retencao_agendado, 'job manual não conta como agendado';
  $minion->perform_jobs;
  my $res = $minion->job($id)->info->{result};
  is $res->{manual}, 1, 'manual';
  ok $res->{resultado}, 'executou';
  ok !exists $res->{proximo}, 'não reagenda';
  is resumo_novo(), $antes + 3, 'registrou as três regras';
  is scalar @{ jobs([qw(inactive active)]) }, 0, 'nada pendente';
};

subtest 'lock: manual para; diária adia' => sub {
  limpa_jobs(); liga();
  ok $minion->lock($TASK, 60), 'lock tomado por outra execução';
  my $m = $app->canais_retencao_executar;
  my $d = $minion->enqueue($TASK => [{}]);
  $minion->perform_jobs;
  is $minion->job($m)->info->{result}, { parado => 'lock' }, 'manual: parado';
  my $res = $minion->job($d)->info->{result};
  is $res->{adiado}, 'lock', 'diária: adiada';
  my $prox = $minion->job($res->{proximo})->info;
  ok $prox->{delayed} > time + 500 && $prox->{delayed} < time + 700, 'reagendada em ~10 min';
  $minion->unlock($TASK);
};

subtest 'boot do worker: inicia (atrasado) se enabled' => sub {
  limpa_jobs(); liga();
  my $w = $minion->worker;
  $w->emit('wait');
  my $j = jobs(['inactive']);
  is scalar @$j, 1, 'um job diário';
  ok $j->[0]{delayed} > time + 3000, '1ª execução atrasada (~1h)';
  $w->emit('wait');
  is scalar @{ jobs(['inactive']) }, 1, 'só uma vez';

  limpa_jobs(); desliga();
  my $w2 = $minion->worker;
  $w2->emit('wait');
  is scalar @{ jobs(['inactive']) }, 0, 'desligada: não inicia';
};

done_testing;
