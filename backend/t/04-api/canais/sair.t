# t/04-api/canais/sair.t
# Opt-out por lista (#216, onda 2 — contrato congelado):
#   GET  /api/canais/sair/:token  200 {escola_nome, lista_nome, ja_saiu} · 404
#   POST /api/canais/sair/:token  JSON {confirmar:true} ou form
#                                 List-Unsubscribe=One-Click → 200 {ok:1, ja_saiu}
#                                 (idempotente) · 400 · 404 · 429
# Independe de canais.inscricao.enabled. O próximo disparo da lista ignora o
# endereço (ignorado_optout); reinscrição pelo QR com o mesmo e-mail desfaz.
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
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.canal_optouts')")
       && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
plan skip_all => 'migration canal_envios nao aplicada' unless $has;

my $model  = $t->app->model('Canal');
my $SECRET = $t->app->secrets->[0];
my $INEP   = 99710000 + ($$ % 1000);
my $P      = sprintf '%04d', $$ % 10000;
my ($gid, $lista, $outra, $qr, %tok, $envio);

sub mail ($n) { return "sair$n.$P\@exemplo.org" }

sub limpa {
  $dbh->do('DELETE FROM clean.canal_envios WHERE cod_inep = ?', {}, $INEP);
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
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.envio.%'
             OR key LIKE 'canais.email.%' OR key LIKE 'canais.inscricao.%'});
}
END { limpa() if $has }

sub cfg ($k, $v) { $model->config_put("canais.$k", $v, 'teste') }
sub dispara ($alvo) {
  my $e = $model->envio_criar(cod_inep => $INEP, gestor_id => $gid, alvo_tipo => 'lista',
    alvo_id => $alvo, operacao => 'aviso', assunto => 'Aviso', corpo => 'Texto.');
  return $model->envio_disparar(cod_inep => $INEP, id => $e->{id}, secret => $SECRET,
                                enqueue => sub { 1 });
}
sub dests ($envio_id) {
  return $dbh->selectall_arrayref(
    q{SELECT d.id, d.status, d.email_hash, c.email
      FROM clean.canal_envio_destinatarios d
      LEFT JOIN clean.contatos c ON c.id = d.contato_id
      WHERE d.envio_id = ? ORDER BY d.id}, { Slice => {} }, $envio_id);
}

limpa();

subtest 'setup: lista com e-mails, disparo com tokens de saída' => sub {
  $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)', {}, $INEP, 'Escola da Saída');
  ($gid) = $dbh->selectrow_array(
    'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
    {}, $INEP, 'Gestor', "gestor.sair.$$\@edumaps.test");
  $lista = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Responsáveis 8º',
                               coleta => 'email')->{id};
  $outra = $model->criar_lista(cod_inep => $INEP, gestor_id => $gid, nome => 'Outra lista',
                               coleta => 'email')->{id};
  $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $lista, gestor_id => $gid);
  for my $n (1, 2) {
    ok $model->registrar_inscricao(token => $qr->{token}, consentimento => 1,
      nome => "Pessoa $n", email => mail($n))->{ok}, "inscrição $n";
  }
  my ($c1) = $dbh->selectrow_array('SELECT id FROM clean.contatos WHERE email = ?', {}, mail(1));
  $dbh->do(q{INSERT INTO clean.canal_lista_membros (lista_id, contato_id, origem)
             VALUES (?, ?, 'manual')}, {}, $outra, $c1);

  cfg('email.enabled', 'true');
  cfg('email.smtp_host', 'smtp.exemplo.org');
  cfg('email.from', 'nao-responda@exemplo.org');
  $envio = dispara($lista);
  is $envio->{status}, 'enviando', 'disparado';
  for my $d (@{ dests($envio->{id}) }) {
    $tok{ $d->{email} } = $model->envio_token_saida($d->{id}, $SECRET);
  }
  is scalar(keys %tok), 2, 'dois tokens';
  ok !$model->inscricao_config->{enabled}, 'autoinscrição desligada não bloqueia a saída';
};

my $URL = sub ($n) { '/api/canais/sair/' . $tok{ mail($n) } };

subtest 'GET: 200 e 404 genérico' => sub {
  $t->get_ok($URL->(1))->status_is(200)
    ->json_is({ escola_nome => 'Escola da Saída', lista_nome => 'Responsáveis 8º', ja_saiu => false });
  $t->get_ok('/api/canais/sair/' . uc $tok{ mail(1) })->status_is(200, 'token sem caixa');
  $t->get_ok('/api/canais/sair/' . ('0' x 32))->status_is(404)->json_has('/error');
  $t->get_ok('/api/canais/sair/nao-e-token')->status_is(404);
  $t->get_ok('/api/canais/sair/' . ('a' x 33))->status_is(404);
};

subtest 'POST: 400 sem confirmação, 404 genérico' => sub {
  $t->post_ok($URL->(1), json => {})->status_is(400)->json_has('/error');
  $t->post_ok($URL->(1), json => { confirmar => false })->status_is(400);
  $t->post_ok($URL->(1), json => { confirmar => [1] })->status_is(400);
  $t->post_ok($URL->(1), form => { 'List-Unsubscribe' => 'Outra-Coisa' })->status_is(400);
  $t->post_ok('/api/canais/sair/' . ('0' x 32), json => { confirmar => true })->status_is(404);
  $t->post_ok('/api/canais/sair/xyz', json => { confirmar => true })->status_is(404);
  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_optouts WHERE lista_id = ?', {}, $lista),
    0, 'nenhuma saída gravada';
};

subtest 'POST JSON: sai e é idempotente' => sub {
  $t->post_ok($URL->(1), json => { confirmar => true })->status_is(200)
    ->json_is({ ok => 1, ja_saiu => false });
  my $o = $dbh->selectall_arrayref(
    'SELECT lista_id, canal, email_hash, envio_id FROM clean.canal_optouts WHERE lista_id IN (?, ?)',
    { Slice => {} }, $lista, $outra);
  is $o, [{ lista_id => $lista, canal => 'email', email_hash => sha256_hex(mail(1)),
            envio_id => $envio->{id} }], 'opt-out só na lista de origem, sem PII';
  $t->post_ok($URL->(1), json => { confirmar => true })->status_is(200)
    ->json_is({ ok => 1, ja_saiu => true });
  $t->get_ok($URL->(1))->status_is(200)->json_is('/ja_saiu', true);
  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_optouts WHERE lista_id = ?', {}, $lista),
    1, 'sem linha nova';
};

subtest 'POST One-Click (RFC 8058)' => sub {
  $t->post_ok($URL->(2), form => { 'List-Unsubscribe' => 'One-Click' })->status_is(200)
    ->json_is({ ok => 1, ja_saiu => false });
  $t->post_ok($URL->(2), form => { 'List-Unsubscribe' => 'One-Click' })->status_is(200)
    ->json_is('/ja_saiu', true);
};

subtest 'próximo disparo ignora quem saiu; outra lista não é afetada' => sub {
  # o envio anterior precisa terminar para não haver dois envios da lista
  $model->envio_cancelar($INEP, $envio->{id});
  my $e2 = dispara($outra);
  is $e2->{status}, 'enviando', 'outra lista: envia normalmente';
  is [ map { $_->{status} } @{ dests($e2->{id}) } ], ['pendente'], 'pessoa 1 segue na outra lista';
  $model->envio_cancelar($INEP, $e2->{id});

  my $r = $model->envio_criar(cod_inep => $INEP, gestor_id => $gid, alvo_tipo => 'lista',
    alvo_id => $lista, operacao => 'aviso', assunto => 'A', corpo => 'B');
  my $x = $model->envio_disparar(cod_inep => $INEP, id => $r->{id}, secret => $SECRET,
                                 enqueue => sub { 1 });
  is $x->{motivo}, 'sem_destinatarios', 'todos saíram: sem destinatários';

  # pessoa 2 se reinscreve pelo QR (POST público) → desfaz o opt-out dela
  cfg('inscricao.enabled', 'true');
  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Pessoa 2', email => uc(mail(2)), consentimento => true })->status_is(201);
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_optouts
       WHERE lista_id = ? AND email_hash = ?}, {}, $lista, sha256_hex(mail(2))), 0,
    'reinscrição desfez o opt-out';
  # honeypot não desfaz
  $t->post_ok("/api/canais/inscricao/$qr->{token}", json => {
    nome => 'Pessoa 1', email => mail(1), consentimento => true, _hp => 'bot' })->status_is(201);
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_optouts
       WHERE lista_id = ? AND email_hash = ?}, {}, $lista, sha256_hex(mail(1))), 1,
    'honeypot não desfaz';

  my $e3 = dispara($lista);
  is $e3->{status}, 'enviando', 'disparo';
  is $e3->{contadores}{destinatarios}, 2, 'dois destinatários (inclui o opt-out)';
  my %st = map { $_->{email_hash} => $_->{status} } @{ dests($e3->{id}) };
  is \%st, { sha256_hex(mail(1)) => 'ignorado_optout', sha256_hex(mail(2)) => 'pendente' },
    'pessoa 1 ignorado_optout; pessoa 2 volta a receber';
  $t->get_ok("/api/gestor/$INEP/canais/envios/$e3->{id}")->status_is(401, 'gestão exige sessão');
};

subtest 'POST: rate limit por token+IP → 429' => sub {
  cfg('inscricao.rate_max', '1');
  my $outro = 'f' x 32;
  $t->post_ok("/api/canais/sair/$outro", json => { confirmar => true })->status_is(404);
  $t->post_ok("/api/canais/sair/$outro", json => { confirmar => true })
    ->status_is(429)->json_has('/error');
  cfg('inscricao.rate_max', '1000');
};

done_testing;
