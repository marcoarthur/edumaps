# t/04-api/chat.t
# Assistente do Censo — POST /api/chat/ask e GET /api/chat/progress.
# Desde a #224 ambas exigem gestor logado e o escopo (contexto) da pergunta
# vem SEMPRE da escola do gestor da sessão (clean.censo_escolas); o
# `contexto` enviado pelo cliente é ignorado.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $minion = $t->app->minion;
my $dbh    = $t->app->schema->storage->dbh;

# --- fixtures ----------------------------------------------------------------
my $INEP  = '77770224';
my $OUTRO = '66660224';
my $SENHA = 'senha123';
my $EMAIL  = sprintf 'chat.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'chat.b.%d@edumaps.test', $$;
my @JOBS;

my $cleanup = sub {
  $minion->backend->remove_job($_) for @JOBS;
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $_) for $EMAIL, $OEMAIL;
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ?', {}, $_) for $INEP, $OUTRO;
};
$cleanup->();
END { $cleanup->() }

$dbh->do(q{INSERT INTO clean.censo_escolas
             (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio,
              sg_uf, no_uf, co_regiao, no_regiao)
           VALUES (2024, ?, 'Escola Antiga', 3, 3509502, 'Campinas', 'SP', 'São Paulo', 3, 'Sudeste'),
                  (2025, ?, 'Escola do Chat', 3, 3509502, 'Campinas', 'SP', 'São Paulo', 3, 'Sudeste'),
                  (2025, ?, 'Outra Escola', 2, 2927408, 'Salvador', 'BA', 'Bahia', 2, 'Nordeste')},
         {}, $INEP, $INEP, $OUTRO);

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Chat', email => $EMAIL, senha => $SENHA,
})->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $OUTRO, nome => 'Gestor Outro', email => $OEMAIL, senha => $SENHA,
})->status_is(200);
my $out_token = $t->post_ok('/api/gestor/login', json => { email => $OEMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
ok $token && $out_token, 'tokens de sessão';

my $auth  = { Authorization => "Bearer $token" };
my $oauth = { Authorization => "Bearer $out_token" };
my $gestor_id = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

# ------------------------------------------------------------
# Sem sessão
# ------------------------------------------------------------
subtest 'sem sessão: ask e progress -> 401' => sub {
  my $antes = $minion->backend->list_jobs(0, 1, { tasks => ['chat_ask'] })->{total};

  $t->post_ok('/api/chat/ask' => json => { pergunta => 'Quantas escolas?' })->status_is(401);
  $t->post_ok('/api/chat/ask' => { Authorization => 'Bearer token-invalido' }
    => json => { pergunta => 'Quantas escolas?' })->status_is(401);
  $t->get_ok('/api/chat/progress?job_id=1')->status_is(401);
  $t->get_ok('/api/chat/progress?job_id=1' => { Accept => 'text/event-stream' })->status_is(401);

  is $minion->backend->list_jobs(0, 1, { tasks => ['chat_ask'] })->{total}, $antes,
    'nenhum job enfileirado sem sessão';
};

# ------------------------------------------------------------
# POST /api/chat/ask
# ------------------------------------------------------------
subtest 'ask: enfileira com o escopo da sessão (contexto do cliente ignorado)' => sub {
  my $tx = $t->post_ok('/api/chat/ask' => $auth => json => {
    pergunta => 'Quantas escolas ativas existem no meu município?',
    contexto => {
      cod_inep       => $OUTRO,
      cod_municipio  => '3550308',
      nome_municipio => 'São Paulo',
      nome_escola    => 'Escola Forjada',
      sg_uf          => 'RJ',
    },
    cod_municipio => '1100015',
  })->status_is(202)->tx;

  my $json = $tx->res->json;
  push @JOBS, $json->{job_id};
  is $json->{task}, 'chat', 'task = chat';
  like $json->{job_id}, qr/^\d+$/, 'job_id numérico';
  like $tx->res->headers->header('Location'), qr{^/api/chat/progress\?job_id=\d+$},
    'Location p/ polling';

  my $info = $minion->job($json->{job_id})->info;
  is $info->{queue}, 'analytics', 'job na fila dedicada analytics';

  my $args = $info->{args}[0];
  is $args->{gestor_id}, "$gestor_id", 'gestor_id da sessão nos args';
  is $args->{cod_inep}, $INEP, 'cod_inep da sessão nos args';
  is $args->{contexto}, {
    cod_inep       => $INEP,
    nome_escola    => 'Escola do Chat',
    cod_municipio  => '3509502',
    nome_municipio => 'Campinas',
    sg_uf          => 'SP',
  }, 'contexto = escola do gestor (edição mais recente do Censo), não o do cliente';
};

subtest 'ask: contexto inválido do cliente não importa (ignorado, 202)' => sub {
  my $json = $t->post_ok('/api/chat/ask' => $auth => json => {
    pergunta => 'Quantas escolas?',
    contexto => { cod_municipio => '123', sg_uf => 'XYZ' },
  })->status_is(202)->tx->res->json;
  push @JOBS, $json->{job_id};
  is $minion->job($json->{job_id})->info->{args}[0]{contexto}{cod_municipio}, '3509502',
    'cod_municipio da sessão';
};

subtest 'ask: validação da pergunta' => sub {
  $t->post_ok('/api/chat/ask' => $auth => json => { contexto => {} })->status_is(400);
  $t->post_ok('/api/chat/ask' => $auth => json => { pergunta => '   ' })->status_is(400);
  $t->post_ok('/api/chat/ask' => $auth => json => { pergunta => 'a' x 501 })->status_is(400);
  $t->post_ok('/api/chat/ask' => $auth => json => [1, 2])->status_is(400);
};

# ------------------------------------------------------------
# GET /api/chat/progress
# ------------------------------------------------------------
subtest 'progress: job inexistente -> 404' => sub {
  $t->get_ok('/api/chat/progress?job_id=999999999' => $auth)
    ->status_is(404)
    ->json_is('/error', 'job_not_found');
};

subtest 'progress: snapshot REST do job do próprio gestor' => sub {
  my $job_id = $JOBS[0];
  $t->get_ok("/api/chat/progress?job_id=$job_id" => $auth)
    ->status_is(200)
    ->json_is('/state', 'inactive');
};

subtest 'progress: job de outro gestor -> 404 (REST e SSE)' => sub {
  my $job_id = $JOBS[0];
  $t->get_ok("/api/chat/progress?job_id=$job_id" => $oauth)
    ->status_is(404)->json_is('/error', 'job_not_found');
  $t->get_ok("/api/chat/progress?job_id=$job_id" => { %$oauth, Accept => 'text/event-stream' })
    ->status_is(404);
};

subtest 'progress: job de outra task -> 404' => sub {
  # Mesmo com os args "do gestor", só jobs chat_ask são consultáveis aqui.
  my $job_id = $minion->enqueue(
    relatorio_gerar => [{ gestor_id => "$gestor_id", cod_inep => $INEP }]
      => { queue => 'chat_test_224' }
  );
  push @JOBS, $job_id;
  $t->get_ok("/api/chat/progress?job_id=$job_id" => $auth)->status_is(404);
};

subtest 'progress: job chat_ask sem gestor nos args (legado) -> 404' => sub {
  my $job_id = $minion->enqueue(
    chat_ask => [{ pergunta => 'x', contexto => {} }] => { queue => 'chat_test_224' }
  );
  push @JOBS, $job_id;
  $t->get_ok("/api/chat/progress?job_id=$job_id" => $auth)->status_is(404);
};

subtest 'progress: SSE com sessão' => sub {
  my $job_id = $minion->enqueue(
    chat_ask => [{ pergunta => 'x', contexto => {}, gestor_id => "$gestor_id", cod_inep => $INEP }]
      => { queue => 'chat_test_224' }
  );
  push @JOBS, $job_id;
  # Progresso em 100%: o monitor abre o stream e o encerra no 1.º poll.
  $minion->job($job_id)->note(progress => { percent => 100, message => 'Resposta gerada' });

  my $tx = $t->get_ok("/api/chat/progress?job_id=$job_id" => { %$auth, Accept => 'text/event-stream' })
    ->status_is(200)->tx;
  like $tx->res->headers->content_type // '', qr{text/event-stream}, 'content-type SSE';
  # (o corpo do stream não é observável pelo Test::Mojo: basta o 200 SSE)
};

subtest 'progress: SSE de job já terminado devolve o snapshot' => sub {
  my $job_id = $minion->enqueue(
    chat_ask => [{ pergunta => 'x', contexto => {}, gestor_id => "$gestor_id", cod_inep => $INEP }]
      => { queue => 'chat_test_224' }
  );
  push @JOBS, $job_id;
  my $worker = $minion->worker->register;
  my $job = $worker->dequeue(0, { queues => ['chat_test_224'], id => $job_id });
  ok $job, 'job tomado pelo worker de teste';
  $job->finish({ resposta => 'São **3** escolas.' });
  $worker->unregister;

  $t->get_ok("/api/chat/progress?job_id=$job_id" => { %$auth, Accept => 'text/event-stream' })
    ->status_is(200)
    ->json_is('/state', 'finished')
    ->json_is('/result/resposta', 'São **3** escolas.');
};

done_testing();
