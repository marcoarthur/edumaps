# t/04-api/canais/confirmacao.t
# Face pública da confirmação de posse do telefone nas listas com QR (issue
# #212 — Fase 1, onda 1):
#   POST /api/canais/inscricao/:token   (+ `confirmacao` quando a lista exige)
#   GET  /api/canais/confirmacao/:ref   (200 pendente/confirmado · 404 genérico)
# Canais disponíveis conforme a config (canais.telegram.* / canais.whatsapp.*).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use JSON::PP ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has        = $dbh->selectrow_array("SELECT to_regclass('clean.canal_confirmacao_refs')");
my $has_config = $dbh->selectrow_array("SELECT to_regclass('app_config.items')");

my $INEP   = 99550000 + ($$ % 999);
my $EMAIL  = sprintf 'gestor.confirmacao.api.%d@edumaps.test', $$;
my $model  = $t->app->model('Canal');
my $MASTER = 'chave-mestra-de-teste-12345';
my ($gestor_id, $tk_exige, $tk_livre);

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

sub limpa_config {
  return unless $has_config;
  $dbh->do(q{DELETE FROM app_config.items
             WHERE key LIKE 'canais.inscricao.%' OR key LIKE 'canais.telegram.%'
                OR key LIKE 'canais.whatsapp.%'});
}

sub habilita_flag {
  $model->config_put('canais.inscricao.enabled', 'true', $EMAIL);
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
}

# Liga o bot público e o WhatsApp Cloud com template (os dois canais).
sub configura_canais {
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;
  $model->config_put('canais.telegram.enabled', 'true', $EMAIL);
  $model->config_put('canais.telegram.token', '123456:ABCDEFGHIJ', $EMAIL);
  $model->config_put('canais.telegram.bot_username', 'EduMapsTesteBot', $EMAIL);
  $model->config_put('canais.whatsapp.enabled', 'true', $EMAIL);
  $model->config_put('canais.whatsapp.provider', 'cloud', $EMAIL);
  $model->config_put('canais.whatsapp.token', 'EAAG-token-teste', $EMAIL);
  $model->config_put('canais.whatsapp.phone_number_id', '123456789012345', $EMAIL);
  $model->config_put('canais.whatsapp.template_confirmacao', 'edumaps_codigo', $EMAIL);
}

sub inscreve ($tk, $nome, $telefone, %extra) {
  return $t->post_ok("/api/canais/inscricao/$tk", json => {
    nome => $nome, telefone => $telefone, consentimento => JSON::PP::true, %extra,
  });
}

if ($has && $has_config) {
  limpa_tudo();
  limpa_config();
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
            ON CONFLICT (codigo_inep) DO NOTHING', {}, $INEP, 'Escola Confirmação API');
  ($gestor_id) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor Confirmação API', $EMAIL);
  my $l1 = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id,
                               nome => 'Exige', exige_confirmacao => 1);
  $tk_exige = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l1->{id},
                                   gestor_id => $gestor_id)->{token};
  my $l2 = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Livre');
  $tk_livre = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l2->{id},
                                   gestor_id => $gestor_id)->{token};
}

END {
  limpa_tudo();
  limpa_config();
}

subtest 'lista sem exigência: resposta idêntica à Fase 0' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  my $r = inscreve($tk_livre, 'Livre Um', '11944440001')->status_is(201)->tx->res->json;
  is $r, { ok => 1 }, 'só {ok:1}, sem confirmacao';
  my $d = inscreve($tk_livre, 'Livre Um', '11944440001')->status_is(201)->tx->res->json;
  is $d, { ok => 1, duplicado => 1 }, 'duplicado, sem confirmacao';
};

subtest 'lista que exige, sem canais configurados: pendente com canais []' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  my $r = inscreve($tk_exige, 'Sem Canal', '11944440002')->status_is(201)->tx->res->json;
  is $r->{ok}, 1, 'ok';
  my $c = $r->{confirmacao};
  is $c->{estado}, 'pendente', 'pendente';
  like $c->{ref}, qr/^[0-9a-f]{32}$/, 'ref 32 hex';
  ok $c->{expira_em}, 'expira_em';
  is $c->{canais}, [], 'canais vazio';

  my $g = $t->get_ok("/api/canais/confirmacao/$c->{ref}")->status_is(200)->tx->res->json;
  is $g, { estado => 'pendente', canais => [], expira_em => $c->{expira_em} }, 'GET pendente';
};

subtest 'honeypot: 201 sem gravar e sem confirmacao' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  my $r = inscreve($tk_exige, 'Bot', '11944440099', _hp => 'x')
    ->status_is(201)->tx->res->json;
  is $r, { ok => 1 }, 'sem confirmacao';
  my $n = $dbh->selectrow_array(
    q{SELECT count(*) FROM clean.canal_inscricoes WHERE telefone_norm = '11944440099'});
  is $n, 0, 'nada gravado';
};

subtest 'canais disponíveis, reinscrição e GET de confirmação' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();
  configura_canais();
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = $MASTER;

  my $r1 = inscreve($tk_exige, 'Ana Canais', '(11) 94444-0003')->status_is(201)->tx->res->json;
  my $c1 = $r1->{confirmacao};
  is $c1->{estado}, 'pendente', 'pendente';
  is $c1->{canais}, [
    { canal => 'telegram', url => "https://t.me/EduMapsTesteBot?start=$c1->{ref}" },
    { canal => 'whatsapp' },
  ], 'telegram (deep link) e whatsapp';
  ok !exists $r1->{contato_id} && !exists $r1->{inscricao_id}, 'sem ids internos';

  my $g = $t->get_ok("/api/canais/confirmacao/$c1->{ref}")->status_is(200)->tx->res->json;
  is $g->{estado}, 'pendente', 'GET pendente';
  is $g->{canais}, $c1->{canais}, 'GET com os mesmos canais';
  is [sort keys %$g], [qw(canais estado expira_em)], 'GET sem PII nem ids';

  # reinscrição do pendente: ref nova; a anterior vira 404
  my $r2 = inscreve($tk_exige, 'Ana Canais', '11944440003')->status_is(201)->tx->res->json;
  is $r2->{duplicado}, 1, 'duplicado';
  my $c2 = $r2->{confirmacao};
  isnt $c2->{ref}, $c1->{ref}, 'ref nova';
  $t->get_ok("/api/canais/confirmacao/$c1->{ref}")->status_is(404)
    ->json_is('/error', 'Confirmação não encontrada.');
  $t->get_ok("/api/canais/confirmacao/$c2->{ref}")->status_is(200)->json_is('/estado', 'pendente');

  # confirma (como o bot fará na onda 2): GET passa a confirmado, sem canais
  ok $model->concluir(ref => $c2->{ref}, via => 'telegram', telegram_chat_id => 77)->{ok},
    'concluído';
  my $gc = $t->get_ok("/api/canais/confirmacao/$c2->{ref}")->status_is(200)->tx->res->json;
  is $gc->{estado}, 'confirmado', 'GET confirmado';
  is $gc->{canais}, [], 'canais vazio quando confirmado';
  ok $gc->{expira_em}, 'expira_em presente';

  # reinscrição de confirmado: só {estado:"confirmado"}
  my $r3 = inscreve($tk_exige, 'Ana Canais', '11944440003')->status_is(201)->tx->res->json;
  is $r3->{confirmacao}, { estado => 'confirmado' }, 'confirmado sem ref';
};

subtest 'GET: formato inválido, inexistente, expirada -> 404' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  $t->get_ok('/api/canais/confirmacao/nao-e-ref')->status_is(404)
    ->json_is('/error', 'Confirmação não encontrada.');
  $t->get_ok('/api/canais/confirmacao/' . ('a' x 31))->status_is(404);
  $t->get_ok('/api/canais/confirmacao/' . ('z' x 32))->status_is(404);
  $t->get_ok('/api/canais/confirmacao/' . ('f' x 32))->status_is(404)
    ->json_is('/error', 'Confirmação não encontrada.');

  my $r = inscreve($tk_exige, 'Expira', '11944440004')->status_is(201)->tx->res->json;
  my $ref = $r->{confirmacao}{ref};
  $dbh->do(q{UPDATE clean.canal_confirmacao_refs SET expira_em = NOW() - interval '1 second'
             WHERE ref_hash = encode(digest(?, 'sha256'), 'hex')}, {}, $ref);
  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(404);
};

subtest 'GET com a feature desligada -> 404' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  my $r = inscreve($tk_exige, 'Flag', '11944440005')->status_is(201)->tx->res->json;
  my $ref = $r->{confirmacao}{ref};
  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(200);
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.inscricao.%'});
  $t->get_ok("/api/canais/confirmacao/$ref")->status_is(404)->json_has('/error');
};

subtest 'GET: rate limit próprio (rate_max x 6) -> 429' => sub {
  plan skip_all => 'migration nao aplicada' unless $has && $has_config;
  habilita_flag();

  my $r = inscreve($tk_exige, 'Polling', '11944440006')->status_is(201)->tx->res->json;
  my $ref = $r->{confirmacao}{ref};
  $model->config_put('canais.inscricao.rate_max', '1', $EMAIL);   # orçamento: 6/janela
  # janela longa: evita virar o tick no meio do teste
  $model->config_put('canais.inscricao.rate_window_seconds', '3600', $EMAIL);
  my @st = map { $t->get_ok("/api/canais/confirmacao/$ref")->tx->res->code } 1 .. 7;
  is [@st[0 .. 5]], [(200) x 6], 'seis consultas permitidas';
  is $st[6], 429, 'a sétima excede';
  $model->config_put('canais.inscricao.rate_max', '1000', $EMAIL);
};

done_testing;
