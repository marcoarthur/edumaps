# t/04-api/admin/envios.t
# Envio por e-mail para listas — admin (#216, onda 2 — contrato congelado):
#   GET  /api/admin/canais/envios        200 {limites, escolas: [{cod_inep, escola_nome,
#                                         enviados_hoje, enviados_30d, falhas_30d,
#                                         optouts_30d, envios_em_curso, suspensao}]}
#   POST /api/admin/canais/envios/suspensoes {cod_inep, motivo} → 201 {suspensao}
#                                         · 400 · 409; envios em curso → suspenso
#   POST /api/admin/canais/envios/suspensoes/:cod_inep/reativar → 200 {ok:1,
#                                         envios_retomados} · 404; agendado (nunca
#                                         começou) / enviando + reenfileira com delay
# Auth 401/403.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_envio_suspensoes')")
  && $dbh->selectrow_array("SELECT to_regclass('app_config.items')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");
plan skip_all => 'migrations nao aplicadas' unless $has;

my $app    = $t->app;
my $model  = $app->model('Canal');
my $minion = $app->minion;
my $SECRET = $app->secrets->[0];
my $INEP   = 99730000 + ($$ % 1000);
my $OUTRA  = $INEP + 1000;
my $P      = sprintf '%04d', $$ % 10000;
my $ADMIN_EMAIL = "admin.envios.$P\@edumaps.test";
my $USER_EMAIL  = "user.envios.$P\@edumaps.test";
my ($admin, $user, $admin_id, $gid, $lista, %e);
my @smtp;
my $smtp = sub ($cfg, $to, $from, $env) { push @smtp, $to; return { ok => 1 } };

sub limpa {
  $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = 'canais_envio'});
  for my $inep ($INEP, $OUTRA) {
    $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE cod_inep = ? AND referente_tipo = 'envio'},
             {}, $inep);
    $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_envio_suspensoes WHERE cod_inep = ?', {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.sessoes s USING clean.gestores g
               WHERE s.gestor_id = g.id AND g.cod_inep = ?', {}, $inep)
      if $dbh->selectrow_array("SELECT to_regclass('clean.sessoes')");
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.envio.%'
             OR key LIKE 'canais.email.%'});
}
END { limpa() if $has }

sub cfg ($k, $v) { $model->config_put("canais.$k", $v, 'teste') }
sub H { return { Authorization => "Bearer $admin" } }
sub status_de ($id) {
  return $dbh->selectrow_array('SELECT status FROM clean.canal_envios WHERE id = ?', {}, $id);
}
sub escola ($painel, $inep) { my ($x) = grep { $_->{cod_inep} == $inep } @{ $painel->{escolas} }; $x }
sub lote ($id) { $model->envio_processar_lote($id, secret => $SECRET, smtp_transport => $smtp) }
sub jobs_pendentes ($id) {
  return scalar $minion->backend->pg->db->query(
    q{SELECT id FROM minion_jobs WHERE task = 'canais_envio' AND state = 'inactive'
       AND (args->0->>'envio_id')::bigint = ?}, $id)->hashes->each;
}
sub novo ($agenda = undef) {
  my $r = $model->envio_criar(cod_inep => $INEP, gestor_id => $gid, alvo_tipo => 'lista',
    alvo_id => $lista, operacao => 'aviso', assunto => 'A', corpo => 'B');
  return $r unless defined $agenda;
  return $model->envio_disparar(cod_inep => $INEP, id => $r->{id}, secret => $SECRET,
    ($agenda ? (agendado_para => $agenda) : ()),
    enqueue => sub ($id, $delay) { $app->canais_envio_enfileirar($id, $delay) });
}

my $BASE = '/api/admin/canais/envios';
limpa();

subtest 'setup' => sub {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)', {}, $inep, "Escola Adm $inep");
  }
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Admin', email => $ADMIN_EMAIL, senha => 'senha123' })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Comum', email => $USER_EMAIL, senha => 'senha123' })->status_is(200);
  $dbh->do(q{UPDATE clean.gestores SET access_role = 'admin' WHERE email = ?}, {}, $ADMIN_EMAIL);
  ($admin_id) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $ADMIN_EMAIL);
  $gid = $admin_id;
  $admin = $t->post_ok('/api/gestor/login', json => { email => $ADMIN_EMAIL, senha => 'senha123' })
    ->status_is(200)->tx->res->json->{token};
  $user = $t->post_ok('/api/gestor/login', json => { email => $USER_EMAIL, senha => 'senha123' })
    ->status_is(200)->tx->res->json->{token};

  $lista = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Resp',
                               coleta => 'email')->{id};
  for my $n (1, 2) {
    my ($cid) = $dbh->selectrow_array(
      'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email) VALUES (?, ?, ?, ?) RETURNING id',
      {}, $INEP, $gid, "P$n", "adm$n.$P\@exemplo.org");
    $dbh->do(q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem)
               VALUES (?, ?, 'manual')}, {}, $lista, $cid);
  }
  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  cfg('email.from', 'nao-responda@exemplo.org');
  cfg('envio.ritmo_por_minuto', '1');

  # E1: imediato, um lote (ritmo 1) → enviando com 1 pendente
  $e{imediato} = novo('');
  is lote($e{imediato}{id})->{reagendar}, 60, 'lote: 1 enviado, reagenda';
  is status_de($e{imediato}{id}), 'enviando', 'E1 enviando';
  # E2: agendado para daqui a 2 dias
  my ($quando) = $dbh->selectrow_array(
    q{SELECT to_char((NOW() + interval '2 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')});
  $e{agendado} = novo($quando);
  is $e{agendado}{status}, 'agendado', 'E2 agendado';
  # E3: rascunho (não é tocado)
  $e{rascunho} = novo();
  $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash) VALUES (?, ?)},
           {}, $lista, sha256_hex("fulano.$P\@exemplo.org"));
  is scalar @smtp, 1, 'um e-mail enviado';
};

subtest 'auth: 401 sem token, 403 gestor comum' => sub {
  my $U = { Authorization => "Bearer $user" };
  $t->get_ok($BASE)->status_is(401);
  $t->get_ok($BASE, $U)->status_is(403);
  $t->post_ok("$BASE/suspensoes", $U, json => { cod_inep => $INEP, motivo => 'x' })->status_is(403);
  $t->post_ok("$BASE/suspensoes/$INEP/reativar", $U)->status_is(403);
};

subtest 'GET: limites e volume por escola' => sub {
  my $p = $t->get_ok($BASE, H())->status_is(200)
    ->json_is('/limites', { enabled => true, ritmo_por_minuto => 1, cota_diaria => 500,
                            max_destinatarios => 2000, smtp_disponivel => true })
    ->tx->res->json;
  is escola($p, $INEP), {
    cod_inep => $INEP, escola_nome => "Escola Adm $INEP", enviados_hoje => 1, enviados_30d => 1,
    falhas_30d => 0, optouts_30d => 1, envios_em_curso => 2, suspensao => undef,
  }, 'escola com envio';
  ok !escola($p, $OUTRA), 'escola sem envio nem suspensão fica de fora';
};

my $susp;
subtest 'POST suspensoes: 400, 201, envios em curso → suspenso, 409' => sub {
  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => 'abc', motivo => 'spam' })->status_is(400);
  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => $INEP })->status_is(400);
  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => $INEP, motivo => '   ' })->status_is(400);
  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => $INEP, motivo => 'x' x 501 })->status_is(400);
  $t->post_ok("$BASE/suspensoes", H(), json => [1])->status_is(400);

  $susp = $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => $INEP, motivo => ' Denúncias de spam ' })
    ->status_is(201)->json_is('/suspensao/motivo', 'Denúncias de spam')
    ->json_is('/suspensao/suspenso_por', $admin_id)->json_like('/suspensao/suspenso_em', qr/Z$/)
    ->json_has('/suspensao/id')->tx->res->json->{suspensao};
  is status_de($e{imediato}{id}), 'suspenso', 'enviando → suspenso';
  is status_de($e{agendado}{id}), 'suspenso', 'agendado → suspenso';
  is status_de($e{rascunho}{id}), 'rascunho', 'rascunho intacto';

  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => $INEP, motivo => 'de novo' })->status_is(409);
  $t->post_ok("$BASE/suspensoes", H(), json => { cod_inep => "$OUTRA", motivo => 'preventiva' })
    ->status_is(201);

  my $p = $t->get_ok($BASE, H())->status_is(200)->tx->res->json;
  is escola($p, $INEP)->{suspensao}, $susp, 'suspensão no painel';
  is escola($p, $INEP)->{envios_em_curso}, 2, 'suspensos contam como em curso';
  ok escola($p, $OUTRA), 'escola só com suspensão aparece';
  my @ord = map { $_->{cod_inep} } grep { $_->{cod_inep} == $INEP || $_->{cod_inep} == $OUTRA }
    @{ $p->{escolas} };
  is \@ord, [$INEP, $OUTRA], 'ordem por enviados_30d';

  is lote($e{imediato}{id}), { fim => 'suspenso' }, 'job sai sem enviar';
  is scalar @smtp, 1, 'nada enviado';
  is $model->envio_limites($INEP)->{suspensao}{motivo}, 'Denúncias de spam', 'gestor vê a suspensão';
};

subtest 'POST reativar: 404, retomada com o delay certo' => sub {
  $t->post_ok("$BASE/suspensoes/99999999/reativar", H())->status_is(404)->json_has('/error');
  is jobs_pendentes($e{imediato}{id}), 1, 'job do disparo ainda na fila';

  $t->post_ok("$BASE/suspensoes/$INEP/reativar", H())->status_is(200)
    ->json_is({ ok => 1, envios_retomados => 2 });
  is status_de($e{agendado}{id}), 'agendado', 'nunca começou → agendado';
  is status_de($e{imediato}{id}), 'enviando', 'já começou → enviando';
  is status_de($e{rascunho}{id}), 'rascunho', 'rascunho intacto';

  my $s = $dbh->selectrow_hashref(
    'SELECT reativado_por, reativado_em FROM clean.canal_envio_suspensoes WHERE id = ?', {}, $susp->{id});
  is $s->{reativado_por}, $admin_id, 'reativado_por';
  ok $s->{reativado_em}, 'reativado_em';

  my %job = map {
    $_ => $minion->job(scalar $dbh->selectrow_array(
      'SELECT minion_job_id FROM clean.canal_envios WHERE id = ?', {}, $e{$_}{id}))
  } qw(imediato agendado);
  ok $job{agendado}->info->{delayed} > time + 86_400, 'agendado: delay até agendado_para';
  ok $job{imediato}->info->{delayed} <= time + 5, 'enviando: sem delay';
  is $job{imediato}->info->{args}, [{ envio_id => $e{imediato}{id} }], 'args';
  is jobs_pendentes($e{imediato}{id}), 1, 'job antigo removido: uma só cadeia';
  is jobs_pendentes($e{agendado}{id}), 1, 'agendado: uma só cadeia';

  is lote($e{agendado}{id})->{motivo}, 'agendado', 'agendado não envia antes da hora';
  is status_de($e{agendado}{id}), 'agendado', 'segue agendado';
  is lote($e{imediato}{id})->{fim}, 'concluido', 'retomado: envia o que faltava';
  is scalar @smtp, 2, 'segundo e-mail';

  $t->post_ok("$BASE/suspensoes/$INEP/reativar", H())->status_is(404, 'já reativada');
  my $p = $t->get_ok($BASE, H())->status_is(200)->tx->res->json;
  is escola($p, $INEP)->{suspensao}, undef, 'sem suspensão';
  is escola($p, $INEP)->{enviados_hoje}, 2, 'volume atualizado';
  $t->post_ok("$BASE/suspensoes/$OUTRA/reativar", H())->status_is(200)
    ->json_is('/envios_retomados', 0);
};

done_testing;
