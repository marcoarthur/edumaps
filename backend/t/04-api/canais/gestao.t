# t/04-api/canais/gestao.t
# Testes da API de gestão dos canais (issue #208 — Fase 0): listas nomeadas,
# QR de autoinscrição e membros.
#   GET/POST   /api/gestor/:cod_inep/canais/listas
#   GET/PATCH/DELETE /api/gestor/:cod_inep/canais/listas/:id
#   POST/DELETE /api/gestor/:cod_inep/canais/listas/:id/qrcode
#   GET        /api/gestor/:cod_inep/canais/listas/:id/inscricoes
# Exige sessão do gestor da escola (Bearer) e posse do cod_inep.
# Fase 1 (#212): exige_confirmacao no POST/PATCH, contadores
# membros_confirmados/membros_pendentes e estado da confirmação por membro.
# Fase 2 (#214): `coleta` no POST/PATCH/GET, e-mail e estado por contato
# (telefone_estado/email_estado, `parcial`) nos membros, validação de
# expira_em/max_usos do QR.
# Fase 2, onda 2 (#214): DELETE /listas/:id/membros/:membro_id (exclusão pelo
# gestor, anonimiza) e GET /canais/exclusoes (histórico sem PII).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use JSON::PP ();
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
    $dbh->do('DELETE FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $inep)
      if $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')");
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

subtest 'confirmação (#212): POST com exige_confirmacao' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Exige Confirmação', exige_confirmacao => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  is $l->{exige_confirmacao}, T(), 'exige_confirmacao=true';
  is $l->{membros_confirmados}, 0, 'membros_confirmados';
  is $l->{membros_pendentes}, 0, 'membros_pendentes';

  my $s = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Exige String', exige_confirmacao => 'true',
  })->status_is(201)->tx->res->json;
  is $s->{exige_confirmacao}, T(), '"true" aceito';

  my $d = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Default Sem Exigir',
  })->status_is(201)->tx->res->json;
  is $d->{exige_confirmacao}, F(), 'default false';

  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Booleano Ruim', exige_confirmacao => 'talvez',
  })->status_is(400)->json_has('/error');

  my $lista = $t->get_ok("/api/gestor/$INEP/canais/listas", $auth->())
    ->status_is(200)->tx->res->json;
  my ($na) = grep { $_->{id} == $l->{id} } @$lista;
  is $na->{exige_confirmacao}, T(), 'exige_confirmacao na listagem';
  ok exists $na->{membros_confirmados} && exists $na->{membros_pendentes}, 'contadores na listagem';
};

subtest 'confirmação (#212): PATCH da lista' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Para Editar',
  })->status_is(201)->tx->res->json;
  my $id = $l->{id};

  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", json => { nome => 'X' })
    ->status_is(401);
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $out_auth->(), json => { nome => 'X' })
    ->status_is(403)->json_has('/error');
  $t->patch_ok("/api/gestor/$OUTRA/canais/listas/$id", $out_auth->(), json => { nome => 'X' })
    ->status_is(404)->json_has('/error');
  $t->patch_ok("/api/gestor/$INEP/canais/listas/999999999", $auth->(), json => { nome => 'X' })
    ->status_is(404)->json_has('/error');

  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => {})
    ->status_is(400)->json_has('/error');
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => { exige_confirmacao => 'talvez' })
    ->status_is(400)->json_has('/error');
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => { nome => '' })
    ->status_is(400)->json_has('/error');
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => { nome => 'Exige Confirmação' })
    ->status_is(409)->json_has('/error');

  my $u = $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => {
    nome => 'Editada', descricao => 'Nova descrição', exige_confirmacao => JSON::PP::true,
  })->status_is(200)->tx->res->json;
  is $u->{id}, $id, 'detalhe da mesma lista';
  is $u->{nome}, 'Editada', 'nome';
  is $u->{descricao}, 'Nova descrição', 'descricao';
  is $u->{exige_confirmacao}, T(), 'exige_confirmacao ligada';
  ok exists $u->{n_inscricoes}, 'resposta é o detalhe';

  my $u2 = $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => {
    exige_confirmacao => 0,
  })->status_is(200)->tx->res->json;
  is $u2->{exige_confirmacao}, F(), 'exige_confirmacao desligada (0)';
  is $u2->{nome}, 'Editada', 'nome intacto';
};

subtest 'confirmação (#212): contadores e estado por membro' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  my $has_refs = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
  plan skip_all => 'clean.canal_confirmacao_refs ausente' unless $has_refs;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Com Estado', exige_confirmacao => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  my $id = $l->{id};
  my $qr = $t->post_ok("/api/gestor/$INEP/canais/listas/$id/qrcode", $auth->())
    ->status_is(201)->tx->res->json;

  my $model = $t->app->model('Canal');
  my $a = $model->registrar_inscricao(token => $qr->{token}, nome => 'Pendente',
                                      telefone => '11966661111', consentimento => 1);
  my $b = $model->registrar_inscricao(token => $qr->{token}, nome => 'Confirmada',
                                      telefone => '11966662222', consentimento => 1);
  ok $a->{ok} && $b->{ok}, 'duas inscrições';
  ok $model->concluir(ref => $b->{confirmacao}{ref}, via => 'whatsapp')->{ok}, 'uma confirmada';

  my $d = $t->get_ok("/api/gestor/$INEP/canais/listas/$id", $auth->())
    ->status_is(200)->tx->res->json;
  is $d->{membros_confirmados}, 1, 'detalhe: 1 confirmado';
  is $d->{membros_pendentes}, 1, 'detalhe: 1 pendente';

  my $rows = $t->get_ok("/api/gestor/$INEP/canais/listas/$id/inscricoes", $auth->())
    ->status_is(200)->tx->res->json;
  my %por_nome = map { $_->{nome} => $_ } @$rows;
  is $por_nome{Pendente}{estado}, 'pendente', 'estado pendente';
  ok !defined $por_nome{Pendente}{confirmado_via}, 'pendente sem via';
  ok !defined $por_nome{Pendente}{confirmado_em}, 'pendente sem data';
  is $por_nome{Confirmada}{estado}, 'confirmado', 'estado confirmado';
  is $por_nome{Confirmada}{confirmado_via}, 'whatsapp', 'via';
  ok $por_nome{Confirmada}{confirmado_em}, 'data da confirmação';
  is $por_nome{Confirmada}{validado}, 1, 'validado=1 após confirmar';

  # desligar a exigência: pendente vira nao_exigida; confirmado continua
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$id", $auth->(), json => {
    exige_confirmacao => JSON::PP::false,
  })->status_is(200)->json_is('/membros_pendentes', 0)->json_is('/membros_confirmados', 1);
  my $rows2 = $t->get_ok("/api/gestor/$INEP/canais/listas/$id/inscricoes", $auth->())
    ->status_is(200)->tx->res->json;
  my %p2 = map { $_->{nome} => $_ } @$rows2;
  is $p2{Pendente}{estado}, 'nao_exigida', 'sem exigência -> nao_exigida';
  is $p2{Confirmada}{estado}, 'confirmado', 'confirmado preservado';
};

subtest 'coleta (#214): POST, PATCH, listar, detalhe; inválida -> 400' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Coleta Default',
  })->status_is(201)->json_is('/coleta', 'telefone')->tx->res->json;

  my $e = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Coleta Email', coleta => 'email',
  })->status_is(201)->json_is('/coleta', 'email')->tx->res->json;

  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Coleta Ruim', coleta => 'sms',
  })->status_is(400)->json_like('/error', qr/coleta/);
  ok !$dbh->selectrow_array(
    'SELECT 1 FROM clean.canal_listas WHERE cod_inep = ? AND nome = ?', {}, $INEP, 'Coleta Ruim'),
    'lista inválida não criada';

  $t->patch_ok("/api/gestor/$INEP/canais/listas/$l->{id}", $auth->(), json => {
    coleta => 'ambos',
  })->status_is(200)->json_is('/coleta', 'ambos');
  $t->patch_ok("/api/gestor/$INEP/canais/listas/$l->{id}", $auth->(), json => {
    coleta => 'nenhum',
  })->status_is(400)->json_like('/error', qr/coleta/);
  $t->get_ok("/api/gestor/$INEP/canais/listas/$l->{id}", $auth->())
    ->status_is(200)->json_is('/coleta', 'ambos');

  my $todas = $t->get_ok("/api/gestor/$INEP/canais/listas", $auth->())
    ->status_is(200)->tx->res->json;
  my %c = map { $_->{nome} => $_->{coleta} } @$todas;
  is $c{'Coleta Default'}, 'ambos', 'listagem com coleta';
  is $c{'Coleta Email'}, 'email', 'listagem com coleta (email)';

  # desativar marca desativada_em; recriar com o mesmo nome reativa e limpa
  $t->delete_ok("/api/gestor/$INEP/canais/listas/$e->{id}", $auth->())->status_is(204);
  my $da = $dbh->selectrow_array(
    'SELECT desativada_em FROM clean.canal_listas WHERE id = ?', {}, $e->{id});
  ok $da, 'desativada_em preenchida';
  $t->delete_ok("/api/gestor/$INEP/canais/listas/$e->{id}", $auth->())->status_is(204);
  is $dbh->selectrow_array(
    'SELECT desativada_em FROM clean.canal_listas WHERE id = ?', {}, $e->{id}), $da,
    'desativar de novo não move desativada_em';
  $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Coleta Email', coleta => 'qualquer',
  })->status_is(201)->json_is('/id', $e->{id})->json_is('/coleta', 'qualquer');
  ok !defined $dbh->selectrow_array(
    'SELECT desativada_em FROM clean.canal_listas WHERE id = ?', {}, $e->{id}),
    'reativação limpa desativada_em';
};

subtest 'membros (#214): e-mail, estado por contato e parcial' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Ambos Exige', coleta => 'ambos', exige_confirmacao => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  my $id = $l->{id};
  my $qr = $t->post_ok("/api/gestor/$INEP/canais/listas/$id/qrcode", $auth->())
    ->status_is(201)->tx->res->json;

  my $model = $t->app->model('Canal');
  my %r;
  for my $n (1 .. 3) {
    $r{$n} = $model->registrar_inscricao(
      token => $qr->{token}, nome => "Pessoa $n", telefone => "1196000000$n",
      email => "pessoa$n.$$\@exemplo.org", consentimento => 1);
    ok $r{$n}{ok}, "inscrição $n";
  }
  # 2: só o telefone (parcial); 3: telefone + e-mail (confirmado)
  $model->concluir(ref => $r{2}{confirmacao}{ref}, via => 'telegram');
  $model->concluir(ref => $r{3}{confirmacao}{ref}, via => 'whatsapp');
  $model->concluir(ref => $r{3}{confirmacao}{ref}, via => 'email');

  my $d = $t->get_ok("/api/gestor/$INEP/canais/listas/$id", $auth->())
    ->status_is(200)->tx->res->json;
  is $d->{membros_confirmados}, 1, 'confirmados = estado geral confirmado';
  is $d->{membros_pendentes}, 2, 'pendentes = pendente + parcial';

  my $rows = $t->get_ok("/api/gestor/$INEP/canais/listas/$id/inscricoes", $auth->())
    ->status_is(200)->tx->res->json;
  my %p = map { $_->{nome} => $_ } @$rows;
  is $p{'Pessoa 1'}{email}, "pessoa1.$$\@exemplo.org", 'e-mail do membro';
  is [@{ $p{'Pessoa 1'} }{qw(estado telefone_estado email_estado)}],
     [qw(pendente pendente pendente)], 'pendente nos dois';
  is [@{ $p{'Pessoa 2'} }{qw(estado telefone_estado email_estado)}],
     [qw(parcial confirmado pendente)], 'parcial';
  ok !defined $p{'Pessoa 2'}{email_confirmado_em}, 'e-mail sem data';
  is [@{ $p{'Pessoa 3'} }{qw(estado telefone_estado email_estado)}],
     [qw(confirmado confirmado confirmado)], 'confirmado nos dois';
  ok $p{'Pessoa 3'}{email_confirmado_em}, 'email_confirmado_em';
  ok exists $p{'Pessoa 1'}{email_confirmado_em}, 'chave email_confirmado_em presente';

  # lista só de telefone: email_estado null (não coletado)
  my $lt = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'Só Tel',
  })->status_is(201)->tx->res->json;
  my $qt = $t->post_ok("/api/gestor/$INEP/canais/listas/$lt->{id}/qrcode", $auth->())
    ->status_is(201)->tx->res->json;
  ok $model->registrar_inscricao(token => $qt->{token}, nome => 'Tel Só',
    telefone => '11960009999', email => 'ignorado@exemplo.org', consentimento => 1)->{ok},
    'inscrição (e-mail ignorado em lista de telefone)';
  my $rt = $t->get_ok("/api/gestor/$INEP/canais/listas/$lt->{id}/inscricoes", $auth->())
    ->status_is(200)->tx->res->json;
  is $rt->[0]{telefone_estado}, 'nao_exigida', 'telefone não exigido';
  ok !defined $rt->[0]{email_estado}, 'email_estado null (não coletado)';
  ok !defined $rt->[0]{email}, 'e-mail não gravado';
  is $rt->[0]{estado}, 'nao_exigida', 'estado geral';
};

subtest 'qrcode (#214): validação de expira_em e max_usos -> 400' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;

  my $l = $t->post_ok("/api/gestor/$INEP/canais/listas", $auth->(), json => {
    nome => 'QR Validado',
  })->status_is(201)->tx->res->json;
  my $url = "/api/gestor/$INEP/canais/listas/$l->{id}/qrcode";

  $t->post_ok($url, $auth->(), json => { expira_em => 'amanhã' })
    ->status_is(400)->json_like('/error', qr/expira_em/);
  $t->post_ok($url, $auth->(), json => { expira_em => '2026-13-45T10:00:00Z' })
    ->status_is(400)->json_like('/error', qr/expira_em/);
  $t->post_ok($url, $auth->(), json => { expira_em => '2020-01-01T00:00:00Z' })
    ->status_is(400)->json_is('/error', 'expira_em deve estar no futuro.');
  for my $m (0, -1, '1.5', 'abc', '10x') {
    $t->post_ok($url, $auth->(), json => { max_usos => $m })
      ->status_is(400, "max_usos $m")->json_like('/error', qr/max_usos/);
  }
  ok !$dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_qrcodes WHERE lista_id = ?', {}, $l->{id}),
    'nenhum QR criado com entrada inválida';

  my $qr = $t->post_ok($url, $auth->(), json => {
    expira_em => '2099-12-31T23:59:00Z', max_usos => 30,
  })->status_is(201)->tx->res->json;
  is $qr->{max_usos}, 30, 'max_usos';
  like $qr->{expira_em}, qr/^2099-12-31/, 'expira_em';
  is $qr->{status}, 'ativo', 'status';
  is $qr->{usos}, 0, 'usos';
  $t->post_ok($url, $auth->(), json => { max_usos => '5', expira_em => '' })
    ->status_is(201)->json_is('/max_usos', 5)->json_is('/expira_em', undef);
  $t->post_ok($url, $auth->(), json => { expira_em => '2099-01-01' })
    ->status_is(201, 'só a data (ISO 8601)');
};

subtest 'exclusão pelo gestor + histórico (#214, onda 2)' => sub {
  plan skip_all => 'migration canal_email_lgpd nao aplicada'
    unless $has && $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')");
  my $model = $t->app->model('Canal');
  my ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

  my $la = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => "Excl A $$");
  my $lb = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => "Excl B $$");
  my %tk = map { $_->{id} => $model->gerar_qrcode(cod_inep => $INEP, lista_id => $_->{id},
                                                  gestor_id => $gid)->{token} } $la, $lb;
  my $tel = sprintf '1194%04d8888', $$ % 10000;
  my $a = $model->registrar_inscricao(token => $tk{ $la->{id} }, consentimento => 1,
                                      nome => 'Pessoa Removida', telefone => $tel);
  my $b = $model->registrar_inscricao(token => $tk{ $lb->{id} }, consentimento => 1,
                                      nome => 'Pessoa Removida', telefone => $tel);
  is $a->{contato_id}, $b->{contato_id}, 'mesmo contato nas duas listas';
  my $base = "/api/gestor/$INEP/canais/listas";
  my $url  = "$base/$la->{id}/membros/$a->{membro_id}";

  $t->delete_ok($url)->status_is(401);
  $t->get_ok("/api/gestor/$INEP/canais/exclusoes")->status_is(401);
  $t->delete_ok($url, $out_auth->())->status_is(403);
  $t->get_ok("/api/gestor/$INEP/canais/exclusoes", $out_auth->())->status_is(403);
  # membro de outra lista / inexistente / lista de outra escola
  $t->delete_ok("$base/$la->{id}/membros/$b->{membro_id}", $auth->())->status_is(404)->json_has('/error');
  $t->delete_ok("$base/$la->{id}/membros/999999999", $auth->())->status_is(404);
  $t->delete_ok("/api/gestor/$OUTRA/canais/listas/$la->{id}/membros/$a->{membro_id}", $out_auth->())
    ->status_is(404, 'lista não é da escola do gestor');

  $t->delete_ok($url, $auth->(), json => { motivo => 'Pedido por telefone à secretaria' })
    ->status_is(200)->json_is({ ok => 1, contatos => 1, inscricoes => 2, membros => 2 });
  is $dbh->selectrow_array('SELECT nome FROM clean.contatos WHERE id = ?', {}, $a->{contato_id}),
    '[removido]', 'contato anonimizado';
  $t->get_ok("$base/$lb->{id}/inscricoes", $auth->())->status_is(200)->json_is('', [], 'saiu também da lista B');
  $t->delete_ok($url, $auth->())->status_is(404, 'já removido');

  my $h = $t->get_ok("/api/gestor/$INEP/canais/exclusoes", $auth->())->status_is(200)->tx->res->json;
  is scalar @$h, 1, 'uma exclusão';
  is $h->[0]{origem}, 'gestor', 'origem';
  is $h->[0]{motivo}, 'Pedido por telefone à secretaria', 'motivo';
  is $h->[0]{gestor_id}, $gid, 'gestor';
  is [ @{ $h->[0] }{qw(contatos inscricoes membros)} ], [1, 2, 2], 'contagens';
  ok !defined $h->[0]{regra}, 'sem regra';
  like $h->[0]{created_at}, qr/T.*Z$/, 'created_at ISO';
  my $json = JSON::PP->new->canonical->encode($h);
  unlike $json, qr/Pessoa Removida|\Q$tel\E/, 'sem PII';

  $t->get_ok("/api/gestor/$OUTRA/canais/exclusoes", $out_auth->())->status_is(200)->json_is('', []);
};

done_testing;
