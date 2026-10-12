# t/04-api/admin/retencao.t
# Retenção (LGPD) — admin (#214, onda 2 — contrato congelado):
#   GET  /api/admin/canais/retencao           200 {enabled, metadados_dias, pendentes_dias,
#                                                  listas_inativas_meses, ultima_execucao
#                                                  {em, metadados, pendentes, listas_inativas}
#                                                  | null, agendado}
#   POST /api/admin/canais/retencao/executar  202 {ok:1, job_id} (avulsa, não reagenda)
# Auth 401/403; folhas canais.retencao.* na árvore de config.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')")
  && $dbh->selectrow_array("SELECT to_regclass('app_config.items')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");
plan skip_all => 'migrations nao aplicadas' unless $has;

my $app    = $t->app;
my $minion = $app->minion;
my $INEP_ADMIN  = '77777773';
my $INEP_USER   = '66666663';
my $ADMIN_EMAIL = sprintf('admin.retencao.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.retencao.%d@edumaps.test', $$);
my $SENHA = 'senha123';
my ($admin, $user);
my ($ex_max) = $dbh->selectrow_array('SELECT COALESCE(max(id), 0) FROM clean.canal_exclusoes');

sub limpa_jobs { $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = 'canais_retencao'}) }
END {
  return unless $has;
  limpa_jobs();
  $dbh->do(q{DELETE FROM clean.canal_exclusoes WHERE origem = 'retencao' AND id > ?}, {}, $ex_max);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.retencao.%'});
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep IN (?, ?)', {}, $INEP_ADMIN, $INEP_USER);
}

sub H { return { Authorization => "Bearer $admin" } }
my $BASE = '/api/admin/canais/retencao';

subtest 'setup' => sub {
  limpa_jobs();
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.retencao.%'});
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, 'Escola teste retenção');
  }
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin', email => $ADMIN_EMAIL, senha => $SENHA })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Comum', email => $USER_EMAIL, senha => $SENHA })->status_is(200);
  $dbh->do(q{UPDATE clean.gestores SET access_role = 'admin' WHERE email = ?}, {}, $ADMIN_EMAIL);
  $admin = $t->post_ok('/api/gestor/login', json => { email => $ADMIN_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  $user = $t->post_ok('/api/gestor/login', json => { email => $USER_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  ok $admin && $user, 'tokens';
};

subtest 'auth: 401 sem token, 403 gestor comum' => sub {
  my $U = { Authorization => "Bearer $user" };
  $t->get_ok($BASE)->status_is(401);
  $t->post_ok("$BASE/executar")->status_is(401);
  $t->get_ok($BASE, $U)->status_is(403);
  $t->post_ok("$BASE/executar", $U)->status_is(403);
  is $minion->jobs({ tasks => ['canais_retencao'] })->total, 0, 'nada enfileirado';
};

subtest 'GET: defaults, sem execução, sem agendamento' => sub {
  my $tem_exec = $dbh->selectrow_array(
    q{SELECT count(*) FROM clean.canal_exclusoes WHERE origem = 'retencao' AND cod_inep = 0});
  my $j = $t->get_ok($BASE, H())->status_is(200)->tx->res->json;
  is [ sort keys %$j ],
     [ sort qw(enabled metadados_dias pendentes_dias listas_inativas_meses ultima_execucao agendado) ],
     'campos do contrato';
  is $j->{enabled}, true, 'enabled (default)';
  is [ @$j{qw(metadados_dias pendentes_dias listas_inativas_meses)} ], [90, 180, 12], 'prazos default';
  is $j->{agendado}, false, 'não agendado';
  ok !defined $j->{ultima_execucao}, 'sem execução' unless $tem_exec;

  # folhas no Painel de Configuração
  my $tree = $t->get_ok('/api/admin/config/tree', H())->status_is(200)->tx->res->json;
  my $json = Mojo::JSON::to_json($tree);
  like $json, qr/Retenção \(LGPD\)/, 'grupo na árvore';
  like $json, qr/canais\.retencao\.$_/, "folha $_"
    for qw(enabled metadados_dias pendentes_dias listas_inativas_meses);
  $t->put_ok('/api/admin/config/canais.retencao.pendentes_dias', H(), json => { value => '200' })
    ->status_is(200);
  $t->get_ok($BASE, H())->status_is(200)->json_is('/pendentes_dias', 200);
};

subtest 'POST executar: 202, avulsa, não reagenda' => sub {
  my $r = $t->post_ok("$BASE/executar", H())->status_is(202)->tx->res->json;
  is $r->{ok}, 1, 'ok';
  ok $r->{job_id} > 0, 'job_id';
  my $info = $minion->job($r->{job_id})->info;
  is $info->{task}, 'canais_retencao', 'task';
  is $info->{args}, [{ manual => 1 }], 'manual';
  $t->get_ok($BASE, H())->status_is(200)->json_is('/agendado', false, 'manual não é agendamento');

  $minion->perform_jobs;
  is $minion->job($r->{job_id})->info->{state}, 'finished', 'executado';
  my $j = $t->get_ok($BASE, H())->status_is(200)->tx->res->json;
  my $u = $j->{ultima_execucao};
  like $u->{em}, qr/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/, 'última execução: em';
  is [ sort keys %$u ], [ sort qw(em metadados pendentes listas_inativas) ], 'campos';
  ok !grep({ $u->{$_} !~ /^\d+$/ } qw(metadados pendentes listas_inativas)), 'contagens numéricas';
  is $j->{agendado}, false, 'continua sem agendamento (não reagendou)';
  is $minion->jobs({ tasks => ['canais_retencao'], states => [qw(inactive active)] })->total, 0,
    'nada pendente';

  $app->canais_retencao_start;
  $t->get_ok($BASE, H())->status_is(200)->json_is('/agendado', true, 'agendado com job diário');
};

done_testing;
