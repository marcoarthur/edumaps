# t/04-api/canais/exclusao.t
# Exclusão a pedido do titular (#214, onda 2 — contrato congelado):
#   GET  /api/canais/exclusao/:token  200 {escola_nome, lista_nome, ja_excluido} · 404
#   POST /api/canais/exclusao/:token  {confirmar:true} → 200 {ok:1, ja_excluido}
#                                     · 400 · 404 · 429
#   GET  /api/canais/consentimento    + retencao {metadados_dias, pendentes_dias,
#                                       listas_inativas_meses, enabled}
# Independe de canais.inscricao.enabled (direito do titular).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON qw(true false);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh   = $t->app->schema->storage->dbh;
my $has   = $dbh->selectrow_array("SELECT to_regclass('clean.canal_exclusoes')")
         && $dbh->selectrow_array("SELECT to_regclass('app_config.items')");
my $model = $t->app->model('Canal');
plan skip_all => 'migration canal_email_lgpd nao aplicada' unless $has;

my $INEP  = 99590000 + ($$ % 1000);
my $P     = sprintf '%04d', $$ % 10000;
my $EMAIL = "gestor.exclusao.api.$$\@edumaps.test";
my ($gestor_id, $insc, $tok);

sub limpa {
  $dbh->do('DELETE FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $INEP);
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
  $dbh->do(q{DELETE FROM app_config.items WHERE key LIKE 'canais.inscricao.%'
                OR key LIKE 'canais.retencao.%'});
}
END { limpa() if $has }
limpa();

$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)', {}, $INEP, 'Escola do Titular');
($gestor_id) = $dbh->selectrow_array(
  'INSERT INTO clean.gestores (cod_inep, nome, email) VALUES (?, ?, ?) RETURNING id',
  {}, $INEP, 'Gestor', $EMAIL);
my $l  = $model->criar_lista(cod_inep => $INEP, gestor_id => $gestor_id, nome => 'Responsáveis 8º');
my $qr = $model->gerar_qrcode(cod_inep => $INEP, lista_id => $l->{id}, gestor_id => $gestor_id);
$insc = $model->registrar_inscricao(token => $qr->{token}, consentimento => 1,
  nome => "Titular $P", telefone => "1193${P}7777");
($tok) = $insc->{exclusao_url} =~ m{/([0-9a-f]{32})$};
my $URL = "/api/canais/exclusao/$tok";

subtest 'flag de autoinscrição desligada não bloqueia' => sub {
  ok !$model->inscricao_config->{enabled}, 'canais.inscricao.enabled desligada';
};

subtest 'GET' => sub {
  $t->get_ok($URL)->status_is(200)
    ->json_is({ escola_nome => 'Escola do Titular', lista_nome => 'Responsáveis 8º',
                ja_excluido => false });
  $t->get_ok('/api/canais/exclusao/' . uc $tok)->status_is(200, 'token sem caixa');
  $t->get_ok('/api/canais/exclusao/' . ('0' x 32))->status_is(404)->json_has('/error');
  $t->get_ok('/api/canais/exclusao/nao-e-token')->status_is(404)->json_has('/error');
  $t->get_ok('/api/canais/exclusao/' . ('a' x 33))->status_is(404);
};

subtest 'POST: 400 sem confirmar, 404 genérico' => sub {
  $t->post_ok($URL, json => {})->status_is(400)->json_has('/error');
  $t->post_ok($URL, json => { confirmar => false })->status_is(400);
  $t->post_ok($URL, json => { confirmar => 'false' })->status_is(400);
  $t->post_ok($URL, json => { confirmar => [1] })->status_is(400);
  $t->post_ok('/api/canais/exclusao/' . ('0' x 32), json => { confirmar => true })->status_is(404);
  $t->post_ok('/api/canais/exclusao/xyz', json => { confirmar => true })->status_is(404);
  is $dbh->selectrow_array('SELECT nome FROM clean.contatos WHERE id = ?', {}, $insc->{contato_id}),
    "Titular $P", 'nada removido';
};

subtest 'POST: exclui e é idempotente' => sub {
  $t->post_ok($URL, json => { confirmar => true })->status_is(200)
    ->json_is({ ok => 1, ja_excluido => false });
  my $c = $dbh->selectrow_hashref('SELECT nome, telefone FROM clean.contatos WHERE id = ?',
                                  {}, $insc->{contato_id});
  is $c, { nome => '[removido]', telefone => undef }, 'contato anonimizado';
  my $ex = $dbh->selectall_arrayref(q{SELECT origem, gestor_id, contatos, inscricoes, membros
      FROM clean.canal_exclusoes WHERE cod_inep = ?}, { Slice => {} }, $INEP);
  is $ex, [{ origem => 'titular', gestor_id => undef, contatos => 1, inscricoes => 1, membros => 1 }],
    'registro de auditoria';

  $t->post_ok($URL, json => { confirmar => true })->status_is(200)
    ->json_is({ ok => 1, ja_excluido => true });
  $t->post_ok($URL, form => { confirmar => '1' })->status_is(200, 'form também')
    ->json_is('/ja_excluido', true);
  $t->get_ok($URL)->status_is(200)->json_is('/ja_excluido', true);
  is $dbh->selectrow_array('SELECT count(*) FROM clean.canal_exclusoes WHERE cod_inep = ?', {}, $INEP),
    1, 'sem registro novo';
};

subtest 'POST: rate limit por token+IP → 429' => sub {
  $model->config_put('canais.inscricao.rate_max', '1', 't');
  my $outro = 'f' x 32;
  $t->post_ok("/api/canais/exclusao/$outro", json => { confirmar => true })->status_is(404);
  $t->post_ok("/api/canais/exclusao/$outro", json => { confirmar => true })
    ->status_is(429)->json_has('/error');
  $model->config_put('canais.inscricao.rate_max', '1000', 't');
};

subtest 'GET /api/canais/consentimento: retenção' => sub {
  $t->get_ok('/api/canais/consentimento')->status_is(200)
    ->json_has('/versao')
    ->json_is('/retencao', { enabled => true, metadados_dias => 90, pendentes_dias => 180,
                              listas_inativas_meses => 12 });
  $model->config_put('canais.retencao.enabled', 'false', 't');
  $model->config_put('canais.retencao.metadados_dias', '30', 't');
  $t->get_ok('/api/canais/consentimento')->status_is(200)
    ->json_is('/retencao/enabled', false)->json_is('/retencao/metadados_dias', 30);
};

done_testing;
