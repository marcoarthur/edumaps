# t/04-api/canais/publico.t
# Testes da face pública da autoinscrição por QR (issue #208 — Fase 0):
#   GET  /api/canais/inscricao/:token
#   POST /api/canais/inscricao/:token
# Sem sessão (o token é a capability): feature flag `canais.inscricao.enabled`,
# resposta mínima sem PII, honeypot, consentimento obrigatório, rate limit,
# estados 200/201/400/404/410/429.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.canal_listas')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");

my $INEP   = 99770000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.publico.%d@edumaps.test', $$;
my $model  = $t->app->model('Canal');
my ($gestor_id, $lista_id, $token);

sub limpa_tudo {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.canal_inscricoes i USING clean.canal_listas l
             WHERE i.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_lista_membros m USING clean.canal_listas l
             WHERE m.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do(q{DELETE FROM clean.canal_qrcodes q USING clean.canal_listas l
             WHERE q.lista_id = l.id AND l.cod_inep = ?}, {}, $INEP);
  $dbh->do('DELETE FROM clean.canal_listas WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.gestores WHERE cod_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
}

sub habilita_flag {
  return unless $has_config;
  $model->config_put('canais.inscricao.enabled', 'true', $EMAIL);
  $model->config_put('canais.inscricao.public_base_url', 'http://edumaps.test', $EMAIL);
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
}

sub desabilita_flag {
  return unless $has_config;
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE $1}, {}, 'canais.inscricao.%');
}

if ($has) {
  limpa_tudo();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING',
    {}, $INEP, 'Escola Pública de Teste');
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Público', $EMAIL);
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Lista Pública');
  $lista_id = $l->{id};
  my $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $lista_id, gestor_id => $gestor_id);
  $token = $qr->{token};
}

END {
  limpa_tudo();
  desabilita_flag();
}

subtest 'flag desligada: endpoint inexistente -> 404' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;

  desabilita_flag();
  $t->get_ok("/api/canais/inscricao/$token")->status_is(404)->json_has('/error');
  $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'X', telefone => '11999990000', consentimento => JSON::PP::true,
  })->status_is(404)->json_has('/error');

  my $n = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_inscricoes WHERE lista_id = ?', {}, $lista_id);
  is $n, 0, 'flag desligada não grava nada';
};

subtest 'GET: formulário mínimo sem PII' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  my $d = $t->get_ok("/api/canais/inscricao/$token")
    ->status_is(200)->tx->res->json;
  is $d->{lista_nome}, 'Lista Pública', 'lista_nome';
  is $d->{escola_nome}, 'Escola Pública de Teste', 'escola_nome';
  is $d->{canal}, 'telefone', 'canal';
  is join(',', @{ $d->{campos} }), 'nome,telefone', 'campos do formulário';
  ok !exists $d->{expira_em} || !defined $d->{expira_em}, 'sem expiração (MVP)';
  ok !exists $d->{inscricoes}, 'não lista inscrições';
  ok !exists $d->{cod_inep}, 'não vaza cod_inep';
  ok !exists $d->{gestor_id}, 'não vaza gestor';
  ok !exists $d->{membros}, 'não vaza membros';
};

subtest 'GET: token inválido/inexistente -> 404; revogado/expirado -> 410' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  $t->get_ok('/api/canais/inscricao/nao-e-um-token')->status_is(404);
  $t->get_ok('/api/canais/inscricao/00000000-0000-4000-8000-000000000000')
    ->status_is(404)->json_has('/error');

  # revogado
  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'A revogar');
  my $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id);
  $model->revogar_qrcode($INEP, $l->{id});
  $t->get_ok("/api/canais/inscricao/$qr->{token}")
    ->status_is(410)->json_has('/error');

  # expirado (inserido direto no banco com validade no passado)
  my $tok_exp = $dbh->selectrow_array('SELECT gen_random_uuid()::text');
  $dbh->do(
    q{INSERT INTO clean.canal_qrcodes (lista_id, token, status, expira_em, criado_por)
      VALUES (?, ?::uuid, 'ativo', NOW() - interval '1 hour', ?)},
    {}, $l->{id}, $tok_exp, $gestor_id);
  $t->get_ok("/api/canais/inscricao/$tok_exp")
    ->status_is(410)->json_has('/error');

  # lista desativada (soft delete) -> 410
  my $l2 = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'A desativar');
  my $qr2 = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l2->{id}, gestor_id => $gestor_id);
  $model->excluir_lista($INEP, $l2->{id});
  $t->get_ok("/api/canais/inscricao/$qr2->{token}")
    ->status_is(410)->json_has('/error');

  # esgotado (max_usos atingido): no GET é link indisponível -> 410 (429 é do POST)
  my $tok_uso = $dbh->selectrow_array('SELECT gen_random_uuid()::text');
  $dbh->do(
    q{INSERT INTO clean.canal_qrcodes (lista_id, token, status, max_usos, usos, criado_por)
      VALUES (?, ?::uuid, 'ativo', 1, 1, ?)},
    {}, $l->{id}, $tok_uso, $gestor_id);
  $t->get_ok("/api/canais/inscricao/$tok_uso")
    ->status_is(410)->json_has('/error');
};

subtest 'POST: validações e consentimento -> 400' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  $t->post_ok("/api/canais/inscricao/$token", json => {
    telefone => '11999990000', consentimento => JSON::PP::true,
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'Sem Telefone', consentimento => JSON::PP::true,
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'Telefone Curto', telefone => '123', consentimento => JSON::PP::true,
  })->status_is(400)->json_has('/error');

  $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'Sem Consentimento', telefone => '11999990000',
  })->status_is(400)->json_has('/error');

  # token inexistente -> 404 mesmo com corpo válido
  $t->post_ok('/api/canais/inscricao/00000000-0000-4000-8000-000000000000', json => {
    nome => 'Z', telefone => '11999990000', consentimento => JSON::PP::true,
  })->status_is(404);
};

subtest 'POST: sucesso, resposta mínima e dedupe não destrutivo' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  my $r1 = $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'Inscrita Feliz', telefone => '(11) 96666-5555',
    consentimento => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  is $r1->{ok}, 1, 'ok=1';
  ok !exists $r1->{contato_id}, 'resposta sem contato_id (sem PII)';
  ok !exists $r1->{inscricao_id}, 'resposta sem id interno';
  ok !exists $r1->{telefone}, 'resposta sem telefone';
  ok !exists $r1->{duplicado}, 'primeira submissão não é duplicada';

  my $membros = $model->listar_inscricoes($INEP, $lista_id);
  is scalar(@$membros), 1, 'um membro na lista';
  is $membros->[0]{nome}, 'Inscrita Feliz', 'membro visível ao gestor';

  # mesma pessoa de novo -> duplicado (reuso do contato; histórico preservado)
  my $r2 = $t->post_ok("/api/canais/inscricao/$token", json => {
    nome => 'Inscrita Feliz', telefone => '11966665555',
    consentimento => JSON::PP::true,
  })->status_is(201)->tx->res->json;
  is $r2->{ok}, 1, 'ok=1 na duplicata';
  is $r2->{duplicado}, 1, 'duplicado=1';

  my $membros2 = $model->listar_inscricoes($INEP, $lista_id);
  is scalar(@$membros2), 1, 'pertencimento idempotente (sem novo membro)';
  my $n_contatos = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.contatos WHERE cod_inep = ? AND telefone IS NOT NULL',
    {}, $INEP);
  is $n_contatos, 1, 'contato reusado (sem duplicar)';
  my $n_insc = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_inscricoes WHERE lista_id = ?', {}, $lista_id);
  is $n_insc, 2, 'duas submissões no histórico (append-only)';
};

subtest 'POST: honeypot responde 201 sem gravar' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Honeypot');
  my $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id);

  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Bot', telefone => '11955554444', consentimento => JSON::PP::true, _hp => 'sou-um-bot',
  })->status_is(201)->json_is('/ok', 1);

  my $n = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_inscricoes WHERE lista_id = ?', {}, $l->{id});
  is $n, 0, 'honeypot não grava inscrição';
  my $m = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.canal_lista_membros WHERE lista_id = ?', {}, $l->{id});
  is $m, 0, 'honeypot não cria membro';
};

subtest 'POST: esgotado (max_usos) -> 429' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();

  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Esgotada');
  my $qr = $model->gerar_qrcode(
    cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id, max_usos => 1);

  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Única', telefone => '11944443333', consentimento => JSON::PP::true,
  })->status_is(201);

  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Excedente', telefone => '11944442222', consentimento => JSON::PP::true,
  })->status_is(429)->json_has('/error');
};

subtest 'POST: rate limit por token+IP -> 429' => sub {
  plan skip_all => 'clean.canal_listas ausente (migration nao aplicada)' unless $has;
  plan skip_all => 'app_config.items ausente (migration nao aplicada)' unless $has_config;
  habilita_flag();
  $model->config_put('canais.inscricao.rate_max', '1', $EMAIL);

  my $l = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Rate limit');
  my $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id);

  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Primeira', telefone => '11933331111', consentimento => JSON::PP::true,
  })->status_is(201);

  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Segunda', telefone => '11933332222', consentimento => JSON::PP::true,
  })->status_is(429)->json_has('/error');

  # restaura o limite alto para não contaminar outras execuções
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
};

done_testing;
