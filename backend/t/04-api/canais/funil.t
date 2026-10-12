# t/04-api/canais/funil.t
# Funil de conversão e saídas na gestão (#216, onda 2 — contrato congelado):
#   GET /api/canais/inscricao/:token   200 soma 1 em canal_qr_acessos (qrcode, dia
#                                      America/Sao_Paulo; upsert); 404/410 não contam
#   GET /api/gestor/:cod_inep/canais/listas/:id/funil?de&ate
#        200 {de, ate, exige_confirmacao, totais, taxas, serie (todos os dias)}
#        · 400 (datas) · 404
#   GET /listas e /listas/:id → + n_optouts; /listas/:id/inscricoes → + optout
#   GET /envios/:id → contadores.optouts (opt-outs gerados pelo envio)
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
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_qr_acessos')")
       && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migration canal_envios nao aplicada' unless $has;

my $model = $t->app->model('Canal');
my $INEP  = 99720000 + ($$ % 1000);
my $OUTRA = $INEP + 1000;
my $P     = sprintf '%04d', $$ % 10000;
my $EMAIL = "gestor.funil.$P\@edumaps.test";
my $OUT_EMAIL = "outra.funil.$P\@edumaps.test";
my ($token, $out_token, $gid, %l, %qr);
my $A  = sub { { Authorization => "Bearer $token" } };
my $AO = sub { { Authorization => "Bearer $out_token" } };
my $B  = "/api/gestor/$INEP/canais";

sub limpa {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
               WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
               WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.sessoes s USING clean.gestores g
               WHERE s.gestor_id = g.id AND g.cod_inep = ?', {}, $inep)
      if $dbh->selectrow_array("SELECT to_regclass('clean.sessoes')");
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.inscricao.%'});
}
END { limpa() if $has }

sub acessos ($qr_id) {
  return $dbh->selectall_arrayref(
    q{SELECT to_char(dia, 'YYYY-MM-DD') AS dia, acessos FROM clean.canal_qr_acessos
       WHERE qrcode_id = ? ORDER BY dia}, { Slice => {} }, $qr_id);
}
my ($HOJE) = $dbh->selectrow_array(
  q{SELECT to_char((NOW() AT TIME ZONE 'America/Sao_Paulo')::date, 'YYYY-MM-DD')});

limpa();
for my $inep ($INEP, $OUTRA) {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)', {}, $inep, "Escola Funil $inep");
}

subtest 'setup: sessões, listas, QRs' => sub {
  for my $s ([$INEP, $EMAIL, \$token], [$OUTRA, $OUT_EMAIL, \$out_token]) {
    my ($inep, $email, $ref) = @$s;
    $t->post_ok('/api/gestor/pesquisas/perfil', json => {
      cod_inep => $inep, nome => 'Gestor Funil', email => $email, senha => 'senha123',
    })->status_is(200);
    $$ref = $t->post_ok('/api/gestor/login', json => { email => $email, senha => 'senha123' })
      ->status_is(200)->tx->res->json->{token};
  }
  ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $l{X} = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Exige',
                              coleta => 'qualquer', exige_confirmacao => 1)->{id};
  $l{N} = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Livre',
                              coleta => 'email')->{id};
  for my $k (qw(X N)) {
    $qr{$k} = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l{$k}, gestor_id => $gid);
  }
  $model->config_put('canais.inscricao.enabled', 'true', 't');
  pass 'ok';
};

subtest 'acessos: só o GET 200 conta; upsert por dia' => sub {
  my $id = $qr{N}{id};
  $dbh->do(q{INSERT INTO clean.canal_qr_acessos (qrcode_id, dia, acessos)
             VALUES (?, (NOW() AT TIME ZONE 'America/Sao_Paulo')::date - 1, 7)}, {}, $id);
  $t->get_ok("/api/canais/inscricao/$qr{N}{token}")->status_is(200)->json_hasnt('/qrcode_id');
  is acessos($id)->[-1], { dia => $HOJE, acessos => 1 }, 'primeiro acesso do dia';
  $t->get_ok("/api/canais/inscricao/$qr{N}{token}")->status_is(200);
  my $a = acessos($id);
  is scalar @$a, 2, 'uma linha por dia';
  is $a->[0]{acessos}, 7, 'ontem intacto';
  is $a->[1], { dia => $HOJE, acessos => 2 }, 'upsert soma';

  $t->get_ok('/api/canais/inscricao/' . '00000000-0000-4000-8000-000000000000')->status_is(404);
  $t->post_ok("$B/listas/$l{N}/qrcode", $A->(), json => {})->status_is(201);
  $t->get_ok("/api/canais/inscricao/$qr{N}{token}")->status_is(410, 'QR rotacionado → 410');
  is acessos($id)->[-1]{acessos}, 2, '410 não conta';
  $t->post_ok("/api/canais/inscricao/$qr{N}{token}", json => {})->status_is(410);
  is acessos($id)->[-1]{acessos}, 2, 'POST não conta';

  $model->config_put('canais.inscricao.enabled', 'false', 't');
  my ($novo) = $dbh->selectrow_array(q{SELECT token::text FROM clean.canal_qrcodes
       WHERE lista_id = ? AND status = 'ativo'}, {}, $l{N});
  $t->get_ok("/api/canais/inscricao/$novo")->status_is(404, 'flag desligada');
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_qr_acessos a
       JOIN clean.canal_qrcodes q ON q.id = a.qrcode_id
       WHERE q.token = ?::uuid}, {}, $novo), 0, 'flag desligada não conta';
  $model->config_put('canais.inscricao.enabled', 'true', 't');
};

my %insc;
subtest 'dados do funil (intervalo fixo no passado)' => sub {
  my $id = $qr{X}{id};
  $dbh->do(q{INSERT INTO clean.canal_qr_acessos (qrcode_id, dia, acessos) VALUES
             (?, '2026-01-01', 10), (?, '2026-01-02', 5), (?, '2025-12-31', 99)},
           {}, $id, $id, $id);
  for my $n (1 .. 4) {
    $insc{$n} = $model->registrar_inscricao(token => $qr{X}{token}, consentimento => 1,
      nome => "Pessoa $n", email => "funil$n.$P\@exemplo.org");
    ok $insc{$n}{ok}, "inscrição $n";
  }
  # 1 e 2 no dia 01/01 (01/01 02:00Z ainda é 31/12 em SP → só a 2ª conta em 01/01)
  my $u = 'UPDATE clean.canal_inscricoes SET created_at = ?::timestamptz WHERE id = ?';
  $dbh->do($u, {}, '2026-01-01 02:00:00+00', $insc{1}{inscricao_id});   # SP: 31/12 23:00
  $dbh->do($u, {}, '2026-01-01 12:00:00-03', $insc{2}{inscricao_id});
  $dbh->do($u, {}, '2026-01-02 12:00:00-03', $insc{3}{inscricao_id});
  $dbh->do($u, {}, '2026-01-02 23:30:00-03', $insc{4}{inscricao_id});
  # confirmados: 2 (e-mail em 03/01) e 3 (e-mail em 02/01); 4 fica pendente
  my $c = q{UPDATE clean.canal_lista_membros SET email_confirmado_em = ?::timestamptz,
                   email_confirmado_via = 'email'
             WHERE lista_id = ? AND contato_id = ?};
  $dbh->do($c, {}, '2026-01-03 09:00:00-03', $l{X}, $insc{2}{contato_id});
  $dbh->do($c, {}, '2026-01-02 15:00:00-03', $l{X}, $insc{3}{contato_id});
  # opt-out em 03/01
  $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash, created_at)
             VALUES (?, ?, '2026-01-03 10:00:00-03')}, {}, $l{X}, sha256_hex("funil1.$P\@exemplo.org"));
  pass 'ok';
};

subtest 'GET funil: formato, série com zeros, taxas' => sub {
  my $f = $t->get_ok("$B/listas/$l{X}/funil?de=2026-01-01&ate=2026-01-04", $A->())->status_is(200)
    ->json_is('/de', '2026-01-01')->json_is('/ate', '2026-01-04')
    ->json_is('/exige_confirmacao', true)
    ->json_is('/totais', { acessos => 15, inscricoes => 3, confirmados => 2, optouts => 1 })
    ->json_is('/taxas', { acesso_inscricao => 0.2, inscricao_confirmacao => 0.6667 })
    ->tx->res->json;
  is $f->{serie}, [
    { dia => '2026-01-01', acessos => 10, inscricoes => 1, confirmados => 0, optouts => 0 },
    { dia => '2026-01-02', acessos => 5,  inscricoes => 2, confirmados => 1, optouts => 0 },
    { dia => '2026-01-03', acessos => 0,  inscricoes => 0, confirmados => 1, optouts => 1 },
    { dia => '2026-01-04', acessos => 0,  inscricoes => 0, confirmados => 0, optouts => 0 },
  ], 'série diária (todos os dias, America/Sao_Paulo)';

  $t->get_ok("$B/listas/$l{X}/funil?de=2025-12-31&ate=2025-12-31", $A->())->status_is(200)
    ->json_is('/totais', { acessos => 99, inscricoes => 1, confirmados => 0, optouts => 0 })
    ->json_is('/taxas/inscricao_confirmacao', 0);

  $t->get_ok("$B/listas/$l{X}/funil?de=2020-01-01&ate=2020-01-02", $A->())->status_is(200)
    ->json_is('/taxas', { acesso_inscricao => undef, inscricao_confirmacao => undef })
    ->json_is('/serie/1', { dia => '2020-01-02', acessos => 0, inscricoes => 0,
                            confirmados => 0, optouts => 0 });
};

subtest 'GET funil: padrão de 30 dias; lista sem exigência → confirmados null' => sub {
  my $f = $t->get_ok("$B/listas/$l{N}/funil", $A->())->status_is(200)
    ->json_is('/ate', $HOJE)->json_is('/exige_confirmacao', false)
    ->json_is('/totais/confirmados', undef)
    ->json_is('/taxas/inscricao_confirmacao', undef)->tx->res->json;
  is scalar @{ $f->{serie} }, 30, '30 dias';
  is $f->{serie}[-1]{dia}, $HOJE, 'termina hoje';
  is $f->{serie}[-1]{acessos}, 2, 'acessos de hoje';
  is $f->{serie}[-2]{acessos}, 7, 'acessos de ontem';
  is $f->{totais}{acessos}, 9, 'total de acessos';
  ok !(grep { defined $_->{confirmados} } @{ $f->{serie} }), 'confirmados null na série';
  is $f->{taxas}{acesso_inscricao}, 0, 'sem inscrições: taxa 0';

  $t->get_ok("$B/listas/$l{X}/funil?ate=2026-01-30", $A->())->status_is(200)
    ->json_is('/de', '2026-01-01')->json_is('/ate', '2026-01-30');
};

subtest 'GET funil: validação 400, 404, 403' => sub {
  for my $q ('de=2026-01-05&ate=2026-01-01', 'de=01/01/2026', 'de=2026-02-30&ate=2026-03-01',
             'ate=2026-13-01', 'de=2025-01-01&ate=2026-01-02') {
    $t->get_ok("$B/listas/$l{X}/funil?$q", $A->())->status_is(400, $q)->json_has('/error');
  }
  $t->get_ok("$B/listas/$l{X}/funil?de=2025-01-01&ate=2026-01-01", $A->())
    ->status_is(200, '366 dias é o máximo');
  $t->get_ok("$B/listas/99999999/funil", $A->())->status_is(404);
  $t->get_ok("$B/listas/$l{X}/funil", $AO->())->status_is(403);
  $t->get_ok("$B/listas/$l{X}/funil")->status_is(401);
};

subtest 'n_optouts, optout por membro e contadores.optouts do envio' => sub {
  my ($envio) = $dbh->selectrow_array(q{INSERT INTO clean.canal_envios
      (cod_inep, gestor_id, alvo_tipo, alvo_id, alvo_nome, operacao, assunto, corpo, status)
      VALUES (?, ?, 'lista', ?, 'Exige', 'aviso', 'A', 'B', 'concluido') RETURNING id},
    {}, $INEP, $gid, $l{X});
  $dbh->do(q{INSERT INTO clean.canal_optouts (lista_id, email_hash, envio_id) VALUES (?, ?, ?)},
           {}, $l{X}, sha256_hex("funil3.$P\@exemplo.org"), $envio);

  my $ls = $t->get_ok("$B/listas", $A->())->status_is(200)->tx->res->json;
  my %n = map { $_->{id} => $_->{n_optouts} } @$ls;
  is \%n, { $l{X} => 2, $l{N} => 0 }, 'n_optouts em /listas';
  $t->get_ok("$B/listas/$l{X}", $A->())->status_is(200)->json_is('/n_optouts', 2);

  my $m = $t->get_ok("$B/listas/$l{X}/inscricoes", $A->())->status_is(200)->tx->res->json;
  my %o = map { $_->{nome} => $_->{optout} } @$m;
  is \%o, { 'Pessoa 1' => true, 'Pessoa 2' => false, 'Pessoa 3' => true, 'Pessoa 4' => false },
    'optout por membro (booleano)';

  $t->get_ok("$B/envios/$envio", $A->())->status_is(200)->json_is('/contadores/optouts', 1);
};

done_testing;
