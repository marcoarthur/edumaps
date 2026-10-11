# t/04-api/canais/gestao.t
# Testes da API de gestão dos canais (issue #208 — Fase 0): listas nomeadas,
# QR de autoinscrição e membros.
#   GET/POST   /api/gestor/:cod_inep/canais/listas
#   GET/DELETE /api/gestor/:cod_inep/canais/listas/:id
#   POST/DELETE /api/gestor/:cod_inep/canais/listas/:id/qrcode
#   GET        /api/gestor/:cod_inep/canais/listas/:id/inscricoes
# Exige sessão do gestor da escola (Bearer) e posse do cod_inep.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_listas')");

my $INEP  = 99780000 + ($$ % 1000);
my $OUTRA = 99890000 + ($$ % 1000);
my $EMAIL = sprintf 'gestor.canais.%d@edumaps.test', $$;
my $OUT_EMAIL = sprintf 'outra.canais.%d@edumaps.test', $$;
my $CPF = sprintf('7654321%04d', $$ % 10000);
my $SENHA = 'senha123';

my $token;
my $out_token;
my $auth     = sub { { Authorization => "Bearer $token" } };
my $out_auth = sub { { Authorization => "Bearer $out_token" } };

sub limpa_tudo {
  return unless $has;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
               WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
               WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
               WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $inep);
    $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

if ($has) {
  limpa_tudo();
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, "Escola de teste canais $inep");
  }
}

END {
  limpa_tudo();
  if ($has) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $OUT_EMAIL);
    $dbh->do('DELETE FROM clean.gestores WHERE cpf = ?', {}, $CPF);
  }
}

subtest 'setup: gestor da escola + sessão' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Gestor Canais', email => $EMAIL, senha => $SENHA,
  })->status_is(200);
  my $login = $t->post_ok('/api/gestor/login', json => {
    email => $EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $token = $login->{token};
  ok $token, 'token de sessão da escola';

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola', email => $OUT_EMAIL, senha => $SENHA,
  })->status_is(200);
  my $out = $t->post_ok('/api/gestor/login', json => {
    email => $OUT_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $out_token = $out->{token};
  ok $out_token, 'token da outra escola';
};

subtest 'sem sessão: 401' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  $t->get_ok("/api/gestor/$INEP/canais/listas")->status_is(401)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/canais/listas", json => { nome => 'X' })->status_is(401);
};

subtest 'posse: gestor de outra escola -> 403' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  $t->get_ok("/api/gestor/$INEP/canais/listas", $out_auth->())
    ->status_is(403)->json_has('/error');
  $t->post_ok("/api/gestor/$INEP/canais/listas", $out_auth->(), json => { nome => 'Invasora' })
    ->status_is(403);
};

subtest 'listas: criar, listar, detalhe, desativar (soft delete)' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Alunos 6ºA', descricao => 'Responsáveis da turma',
  })->status_is(201)->tx->res->json;
  ok $l->{id} > 0, 'lista criada com id';
  is $l->{nome}, 'Alunos 6ºA', 'nome';
  is $l->{canal}, 'telefone', 'canal default';
  is $l->{ativo}, 1, 'ativa';
  is $l->{n_membros}, 0, 'sem membros';
  ok !defined $l->{qrcode}, 'sem QR ainda';
  my $lista_id = $l->{id};

  my $lista = $t->get_ok("/api/gestor/$INEP/canais/listas", $auth->())
    ->status_is(200)->tx->res->json;
  ok ref($lista) eq 'ARRAY', 'listagem é array';
  ok grep({ $_->{id} == $lista_id } @$lista), 'lista aparece na listagem';

  my $d = $t->get_ok("/api/gestor/$INEP/canais/listas/$lista_id", $auth->())
    ->status_is(200)->tx->res->json;
  is $d->{nome}, 'Alunos 6ºA', 'detalhe';
  is $d->{gestor_nome}, 'Gestor Canais', 'gestor_nome';
  is $d->{n_inscricoes}, 0, 'contagem de inscrições';

  $t->get_ok("/api/gestor/$INEP/canais/listas/999999999", $auth->())
    ->status_is(404)->json_has('/error');

  # outra escola, mesmo INEP da rota mas token alheio -> 403; token alheio e
  # INEP da outra escola com id desta lista -> 404 (posse no model).
  $t->get_ok("/api/gestor/$OUTRA/canais/listas/$lista_id", $out_auth->())
    ->status_is(404)->json_has('/error');

  $t->delete_ok("/api/gestor/$INEP/canais/listas/$lista_id", $auth->())->status_is(204);
  my $lista2 = $t->get_ok("/api/gestor/$INEP/canais/listas", $auth->())
    ->status_is(200)->tx->res->json;
  ok !grep({ $_->{id} == $lista_id } @$lista2), 'lista desativada some da listagem';
  my $sobrevive = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_listas WHERE id = ?', {}, $lista_id);
  is $sobrevive, 1, 'linha permanece (sem descarte)';

  # recriar o mesmo nome reativa a mesma linha
  my $re = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Alunos 6ºA',
  })->status_is(201)->tx->res->json;
  is $re->{id}, $lista_id, 'recriar reativa a mesma linha';
  is $re->{ativo}, 1, 'reativada';
};

subtest 'listas: validações e nome duplicado' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => { nome => '' })
    ->status_is(400)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => { nome => 'Reunião de Pais' })
    ->status_is(201);
  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => { nome => 'Reunião de Pais' })
    ->status_is(409)->json_has('/error');

  # canal fora do MVP -> 409 (regra de negócio, não validação de formato)
  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Via SMS', canal => 'sms',
  })->status_is(409)->json_has('/error');
};

subtest 'qrcode: gerar, rotacionar, revogar' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Com QR',
  })->status_is(201)->tx->res->json;
  my $lista_id = $l->{id};

  my $qr1 = $t->post_ok("/api/gestor/$INEP/canais/listas/$lista_id/qrcode", $auth->())
    ->status_is(201)->tx->res->json;
  ok $qr1->{token} =~ /^[0-9a-fA-F-]{36}$/, 'token UUID';
  is $qr1->{status}, 'ativo', 'ativo';
  is $qr1->{usos}, 0, 'usos zerados';
  like $qr1->{url}, qr{/inscricao/\Q$qr1->{token}\E$}, 'url de inscrição montada';

  my $d = $t->get_ok("/api/gestor/$INEP/canais/listas/$lista_id", $auth->())
    ->status_is(200)->tx->res->json;
  is $d->{n_qrcodes_ativos}, 1, 'um QR ativo no detalhe';
  is $d->{qrcode}{token}, $qr1->{token}, 'último QR no detalhe';

  my $qr2 = $t->post_ok("/api/gestor/$INEP/canais/listas/$lista_id/qrcode", $auth->())
    ->status_is(201)->tx->res->json;
  ok $qr2->{token} ne $qr1->{token}, 'rotação gera token novo';
  my $antigo = $dbh->selectrow_hashref(
    'SELECT status FROM clean.canal_qrcodes WHERE token = ?::uuid', {}, $qr1->{token});
  is $antigo->{status}, 'revogado', 'QR anterior revogado na rotação';

  $t->delete_ok("/api/gestor/$INEP/canais/listas/$lista_id/qrcode", $auth->())
    ->status_is(204);
  my $rev = $dbh->selectrow_hashref(
    'SELECT status, revogado_em FROM clean.canal_qrcodes WHERE token = ?::uuid', {}, $qr2->{token});
  is $rev->{status}, 'revogado', 'QR revogado';
  ok defined $rev->{revogado_em}, 'revogado_em marcado';

  $t->delete_ok("/api/gestor/$INEP/canais/listas/$lista_id/qrcode", $auth->())
    ->status_is(404)->json_has('/error');

  $t->post_ok("/api/gestor/$INEP/canais/listas/999999999/qrcode", $auth->())
    ->status_is(404)->json_has('/error');
  $t->delete_ok("/api/gestor/$INEP/canais/listas/999999999/qrcode", $auth->())
    ->status_is(404)->json_has('/error');
};

subtest 'inscricoes: membros da lista' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Com Membros',
  })->status_is(201)->tx->res->json;
  my $lista_id = $l->{id};
  my $qr = $t->post_ok("/api/gestor/$INEP/canais/listas/$lista_id/qrcode", $auth->())
    ->status_is(201)->tx->res->json;

  # grava uma inscrição via regra de negócio (a face pública é testada em publico.t)
  my $model = $t->app->model('Canal');
  my $r = $model->registrar_inscricao(
    token => $qr->{token}, nome => 'Membro Um', telefone => '(11) 97777-6666',
    consentimento => 1,
  );
  ok $r->{ok}, 'inscrição registrada no setup';

  my $rows = $t->get_ok("/api/gestor/$INEP/canais/listas/$lista_id/inscricoes", $auth->())
    ->status_is(200)->tx->res->json;
  is ref($rows), 'ARRAY', 'array de membros';
  is scalar(@$rows), 1, 'um membro';
  is $rows->[0]{nome}, 'Membro Um', 'nome do membro';
  is $rows->[0]{telefone}, '(11) 97777-6666', 'telefone (PII restrita ao gestor)';
  is $rows->[0]{origem}, 'qrcode', 'origem';
  is $rows->[0]{validado}, 0, 'não validado (MVP)';
  ok $rows->[0]{quando}, 'quando preenchido';

  $t->get_ok("/api/gestor/$INEP/canais/listas/999999999/inscricoes", $auth->())
    ->status_is(404)->json_has('/error');
};

done_testing;
