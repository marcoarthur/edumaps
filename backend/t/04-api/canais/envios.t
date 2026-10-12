# t/04-api/canais/envios.t
# API de envio por e-mail para listas (#216, onda 1 — contrato congelado):
#   GET/POST         /api/gestor/:cod_inep/canais/envios
#   GET              /api/gestor/:cod_inep/canais/envios/limites
#   GET/PATCH/DELETE /api/gestor/:cod_inep/canais/envios/:id
#   POST             .../envios/:id/{previa,teste,disparar,cancelar}
#   GET              .../envios/:id/destinatarios
#   GET/POST         /api/gestor/:cod_inep/canais/segmentos
#   POST             /api/gestor/:cod_inep/canais/segmentos/previa
#   GET/PUT/DELETE   /api/gestor/:cod_inep/canais/segmentos/:id
#   GET              /api/gestor/:cod_inep/canais/segmentos/:id/previa
# Bearer + posse (401/403), 400/404/409/429, e-mails mascarados. SMTP simulado
# (helper canais_smtp); o job `canais_envio` roda por perform_jobs.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my @enviados;
$t->app->helper(canais_smtp => sub {
  sub ($cfg, $to, $from, $envelope) {
    push @enviados, { to => $to, envelope => $envelope };
    return { ok => 1 };
  };
});

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_envios')")
       && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migration canal_envios nao aplicada' unless $has;

my $model  = $t->app->model('Canal');
my $minion = $t->app->minion;
my $INEP   = 99680000 + ($$ % 1000);
my $OUTRA  = $INEP + 1000;
my $P      = sprintf '%04d', $$ % 10000;
my $EMAIL  = "gestor.envios.$P\@edumaps.test";
my $OUT_EMAIL = "outra.envios.$P\@edumaps.test";
my $SENHA  = 'senha123';
my ($token, $out_token, %l, $gid);
my $A  = sub { { Authorization => "Bearer $token" } };
my $AO = sub { { Authorization => "Bearer $out_token" } };
my $B  = "/api/gestor/$INEP/canais";

sub mail ($n) { return "api$n.$P\@exemplo.org" }

sub limpa {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE cod_inep = ?
               AND referente_tipo IN ('envio', 'envio_teste')}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.canal_segmentos WHERE cod_inep = ?', {}, $inep);
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
             OR key LIKE 'canais.email.%' OR key = 'canais.inscricao.public_base_url'});
  $minion->backend->pg->db->query(q{DELETE FROM minion_jobs WHERE task = 'canais_envio'});
}
END { limpa() if $has }

sub cfg ($k, $v) { $model->config_put("canais.$k", $v, 'teste') }

limpa();
for my $inep ($INEP, $OUTRA) {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, "Escola API $inep");
}

subtest 'setup: sessões, listas e membros' => sub {
  for my $s ([$INEP, $EMAIL, \$token], [$OUTRA, $OUT_EMAIL, \$out_token]) {
    my ($inep, $email, $ref) = @$s;
    $t->post_ok('/api/gestor/pesquisas/perfil', json => {
      cod_inep => $inep, nome => 'Gestor Envios', email => $email, senha => $SENHA,
    })->status_is(200);
    $$ref = $t->post_ok('/api/gestor/login', json => { email => $email, senha => $SENHA })
      ->status_is(200)->tx->res->json->{token};
    ok $$ref, "token $inep";
  }
  ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  my ($gout) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $OUT_EMAIL);
  $l{A} = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Resp 8º',
                              coleta => 'email')->{id};
  $l{B} = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Resp 9º',
                              coleta => 'email')->{id};
  $l{Z} = $model->criar_lista(cod_inep => $OUTRA, gestor_id => $gout, nome => 'Outra',
                              coleta => 'email')->{id};
  my $n = 0;
  for my $def ([A => 1], [A => 2], [B => 2], [B => 3]) {
    my ($lista, $i) = @$def;
    my ($cid) = $dbh->selectrow_array('SELECT id FROM clean.contatos WHERE cod_inep = ? AND email = ?',
                                      {}, $INEP, mail($i));
    ($cid) = $dbh->selectrow_array(
      'INSERT INTO clean.contatos (cod_inep, gestor_id, nome, email) VALUES (?, ?, ?, ?) RETURNING id',
      {}, $INEP, $gid, "Pessoa $i", mail($i)) unless $cid;
    $dbh->do(q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem)
               VALUES (?, ?, 'manual')}, {}, $l{$lista}, $cid);
  }
  pass 'ok';
};

subtest 'sem sessão 401; outra escola 403' => sub {
  $t->get_ok("$B/envios")->status_is(401);
  $t->get_ok("$B/segmentos")->status_is(401);
  $t->get_ok("$B/envios", $AO->())->status_is(403);
  $t->post_ok("$B/envios", $AO->(), json => {})->status_is(403);
  $t->get_ok("$B/envios/limites", $AO->())->status_is(403);
  $t->get_ok("$B/segmentos", $AO->())->status_is(403);
  $t->post_ok("$B/segmentos/previa", $AO->(), json => {})->status_is(403);
};

my $seg;
subtest 'segmentos: CRUD, 400/404/409, prévia mascarada' => sub {
  $t->post_ok("$B/segmentos", $A->(), json => { nome => 'X' })->status_is(400)->json_has('/error');
  $t->post_ok("$B/segmentos", $A->(), json => { nome => 'X', criterios => { listas => [ $l{Z} ] } })
    ->status_is(400);
  $t->post_ok("$B/segmentos", $A->(), json => { nome => 'X',
    criterios => { listas => [ $l{A} ], estado => ['outro'] } })->status_is(400);

  $seg = $t->post_ok("$B/segmentos", $A->(), json => { nome => '8º e 9º',
    criterios => { listas => [ $l{A}, $l{B} ], email_confirmado => undef } })
    ->status_is(201)->json_is('/nome', '8º e 9º')
    ->json_is('/listas/0', { id => $l{A}, nome => 'Resp 8º', existe => JSON::PP::true })
    ->json_is('/criterios/estado', [])->tx->res->json;
  $t->post_ok("$B/segmentos", $A->(), json => { nome => '8º e 9º',
    criterios => { listas => [ $l{A} ] } })->status_is(409);

  $t->get_ok("$B/segmentos", $A->())->status_is(200)->json_is('/0/id', $seg->{id});
  $t->get_ok("$B/segmentos/$seg->{id}", $A->())->status_is(200)->json_is('/nome', '8º e 9º');
  $t->get_ok("/api/gestor/$OUTRA/canais/segmentos/$seg->{id}", $AO->())->status_is(404);
  $t->get_ok("$B/segmentos/99999999", $A->())->status_is(404);

  $t->post_ok("$B/segmentos/previa", $A->(), json => { criterios => { listas => [ $l{A}, $l{B} ] } })
    ->status_is(200)->json_is('/destinatarios', 3)->json_is('/listas_ignoradas', []);
  my $p = $t->get_ok("$B/segmentos/$seg->{id}/previa", $A->())->status_is(200)
    ->json_is('/destinatarios', 3)->tx->res->json;
  ok !(grep { $_->{email} !~ /^a\*\*\*\@e\*\*\*\.org$/ } @{ $p->{amostra} }), 'amostra mascarada';
  $t->post_ok("$B/segmentos/previa", $A->(), json => { criterios => { listas => [] } })->status_is(400);

  my $s2 = $t->post_ok("$B/segmentos", $A->(), json => { nome => 'Só 8º',
    criterios => { listas => [ $l{A} ] } })->status_is(201)->tx->res->json;
  $t->put_ok("$B/segmentos/$s2->{id}", $A->(), json => { nome => '8º e 9º',
    criterios => { listas => [ $l{A} ] } })->status_is(409);
  $t->put_ok("$B/segmentos/$s2->{id}", $A->(), json => { nome => 'Só 8º',
    criterios => { listas => 'x' } })->status_is(400);
  $t->put_ok("$B/segmentos/$s2->{id}", $A->(), json => { nome => 'Só o 8º',
    criterios => { listas => [ $l{A} ], estado => ['nao_exigida'] } })
    ->status_is(200)->json_is('/nome', 'Só o 8º')->json_is('/criterios/estado', ['nao_exigida']);
  $t->put_ok("$B/segmentos/99999999", $A->(), json => { nome => 'Z',
    criterios => { listas => [ $l{A} ] } })->status_is(404);
  $t->delete_ok("$B/segmentos/$s2->{id}", $A->())->status_is(200)->json_is('/ok', 1);
  $t->delete_ok("$B/segmentos/$s2->{id}", $A->())->status_is(404);
};

my $env;
subtest 'envios: rascunho, 400/404/409' => sub {
  $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'lista', alvo_id => $l{A},
    operacao => 'confirmacao', assunto => 'a', corpo => 'b' })->status_is(400);
  $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'lista', alvo_id => $l{A},
    operacao => 'aviso', assunto => '', corpo => 'b' })->status_is(400);
  $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'lista', alvo_id => $l{Z},
    operacao => 'aviso', assunto => 'a', corpo => 'b' })->status_is(404);

  $env = $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'segmento', alvo_id => $seg->{id},
    operacao => 'aviso', assunto => 'Reunião de pais', corpo => 'Na sexta.' })
    ->status_is(201)->json_is('/status', 'rascunho')->json_is('/canal', 'email')
    ->json_is('/alvo', { tipo => 'segmento', id => $seg->{id}, nome => '8º e 9º' })
    ->json_is('/contadores/destinatarios', 0)->json_is('/autor/id', $gid)
    ->json_is('/corpo', 'Na sexta.')->tx->res->json;

  $t->get_ok("$B/envios", $A->())->status_is(200)->json_is('/total', 1)->json_is('/page', 1)
    ->json_is('/per_page', 20)->json_is('/items/0/id', $env->{id})->json_hasnt('/items/0/corpo');
  $t->get_ok("$B/envios?status=bla", $A->())->status_is(400);
  $t->get_ok("$B/envios/$env->{id}", $A->())->status_is(200)->json_is('/assunto', 'Reunião de pais');
  $t->get_ok("/api/gestor/$OUTRA/canais/envios/$env->{id}", $AO->())->status_is(404);
  $t->patch_ok("$B/envios/$env->{id}", $A->(), json => { assunto => 'Reunião de pais e mestres' })
    ->status_is(200)->json_is('/assunto', 'Reunião de pais e mestres');
  $t->patch_ok("$B/envios/$env->{id}", $A->(), json => { operacao => 'x' })->status_is(400);
  $t->patch_ok("$B/envios/99999999", $A->(), json => { assunto => 'x' })->status_is(404);

  $t->post_ok("$B/envios/$env->{id}/previa", $A->())->status_is(200)
    ->json_is('/assunto', 'Reunião de pais e mestres')
    ->json_is('/estimativa', { destinatarios => 3, ignorados_optout => 0, ignorados_duplicado => 1 })
    ->json_like('/texto', qr{Na sexta\.\n\n--\n.*/privacidade/sair/EXEMPLO}s);
};

subtest 'teste e disparo: 409 por motivo, 429, 202' => sub {
  $t->post_ok("$B/envios/$env->{id}/teste", $A->())->status_is(409)
    ->json_is('/motivo', 'smtp_indisponivel');
  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => {})->status_is(409)
    ->json_is('/motivo', 'smtp_indisponivel')->json_has('/error');
  $t->get_ok("$B/envios/limites", $A->())->status_is(200)
    ->json_is('/smtp_disponivel', JSON::PP::false)->json_is('/enabled', JSON::PP::true)
    ->json_is('/cota_diaria', 500)->json_is('/ritmo_por_minuto', 60)
    ->json_is('/max_destinatarios', 2000)->json_is('/suspensao', undef);

  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  cfg('email.from', 'nao-responda@exemplo.org');
  cfg('inscricao.public_base_url', 'https://edumaps.exemplo.org');

  $t->post_ok("$B/envios/$env->{id}/teste", $A->())->status_is(202)
    ->json_is('/enviado', 1)->json_is('/para', 'g***@e***.test');
  $t->post_ok("$B/envios/$env->{id}/teste", $A->())->status_is(202) for 2 .. 5;
  $t->post_ok("$B/envios/$env->{id}/teste", $A->())->status_is(429);
  is scalar @enviados, 5, 'cinco testes';

  cfg('envio.max_destinatarios', '2');
  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => {})->status_is(409)
    ->json_is('/motivo', 'acima_do_teto')->json_is('/teto', 2);
  cfg('envio.max_destinatarios', '2000');
  cfg('envio.cota_diaria_escola', '2');
  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => {})->status_is(409)
    ->json_is('/motivo', 'cota_insuficiente')->json_is('/saldo', 2);
  cfg('envio.cota_diaria_escola', '500');
  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => { agendado_para => '2020-01-01T00:00:00Z' })
    ->status_is(400);
  $t->post_ok("/api/gestor/$OUTRA/canais/envios/$env->{id}/disparar", $AO->(), json => {})
    ->status_is(404);

  @enviados = ();
  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => {})->status_is(202)
    ->json_is('/status', 'enviando')->json_is('/contadores/destinatarios', 3)
    ->json_is('/contadores/ignorados', 1)->json_is('/contadores/pendentes', 3);
  my ($job) = $dbh->selectrow_array('SELECT minion_job_id FROM clean.canal_envios WHERE id = ?',
                                    {}, $env->{id});
  ok $job, 'job enfileirado';
  is $minion->job($job)->info->{args}, [{ envio_id => $env->{id} }], 'args do job';

  $t->post_ok("$B/envios/$env->{id}/disparar", $A->(), json => {})->status_is(409)
    ->json_is('/motivo', 'status');
  $t->patch_ok("$B/envios/$env->{id}", $A->(), json => { assunto => 'x' })->status_is(409);
  $t->delete_ok("$B/envios/$env->{id}", $A->())->status_is(409);

  $minion->perform_jobs;
  # o job roda num processo filho (perform_jobs): confere pelo histórico
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens
       WHERE referente_tipo = 'envio' AND referente_id = ? AND status = 'sent'}, {}, $env->{id}),
    3, 'job entregou os três';
  $t->get_ok("$B/envios/$env->{id}", $A->())->status_is(200)->json_is('/status', 'concluido')
    ->json_is('/contadores/enviados', 3)->json_is('/contadores/pendentes', 0)
    ->json_like('/concluido_em', qr/Z$/);
  $t->get_ok("$B/envios/limites", $A->())->status_is(200)->json_is('/enviados_hoje', 3)
    ->json_is('/saldo_hoje', 497);

  my $d = $t->get_ok("$B/envios/$env->{id}/destinatarios?per_page=2", $A->())->status_is(200)
    ->json_is('/total', 3)->json_is('/per_page', 2)->tx->res->json;
  is scalar @{ $d->{items} }, 2, 'página de 2';
  for my $i (@{ $d->{items} }) {
    like $i->{email}, qr/^a\*\*\*\@e\*\*\*\.org$/, 'e-mail mascarado';
    is $i->{status}, 'enviado', 'estado';
    like $i->{processado_em}, qr/Z$/, 'processado_em ISO';
    ok $i->{nome}, 'nome do contato';
  }
  $t->get_ok("$B/envios/$env->{id}/destinatarios?status=zzz", $A->())->status_is(400);
  $t->get_ok("/api/gestor/$OUTRA/canais/envios/$env->{id}/destinatarios", $AO->())->status_is(404);
  $t->post_ok("$B/envios/$env->{id}/cancelar", $A->())->status_is(409)->json_is('/motivo', 'status');
};

subtest 'agendar e cancelar; apagar rascunho' => sub {
  my $e = $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'lista', alvo_id => $l{A},
    operacao => 'lembrete', assunto => 'Lembrete', corpo => 'Amanhã.' })->status_is(201)->tx->res->json;
  my $quando = $dbh->selectrow_array(
    q{SELECT to_char((NOW() + interval '2 days') AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')});
  $t->post_ok("$B/envios/$e->{id}/disparar", $A->(), json => { agendado_para => $quando })
    ->status_is(202)->json_is('/status', 'agendado')->json_is('/agendado_para', $quando)
    ->json_is('/alvo/nome', 'Resp 8º');
  my ($job) = $dbh->selectrow_array('SELECT minion_job_id FROM clean.canal_envios WHERE id = ?',
                                    {}, $e->{id});
  ok $minion->job($job)->info->{delayed} > time + 86_400, 'job com delay';
  $t->post_ok("$B/envios/$e->{id}/cancelar", $A->())->status_is(200)
    ->json_is('/status', 'cancelado')->json_is('/contadores/cancelados', 2);

  my $r = $t->post_ok("$B/envios", $A->(), json => { alvo_tipo => 'lista', alvo_id => $l{B},
    operacao => 'informacao', assunto => 'Info', corpo => 'Texto' })->status_is(201)->tx->res->json;
  $t->delete_ok("$B/envios/$r->{id}", $A->())->status_is(200)->json_is('/ok', 1);
  $t->get_ok("$B/envios/$r->{id}", $A->())->status_is(404);
  $t->get_ok("$B/envios?status=cancelado", $A->())->status_is(200)->json_is('/total', 1);
};

done_testing;
