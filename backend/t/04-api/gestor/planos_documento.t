# t/04-api/gestor/planos_documento.t
# #385 (épico #368): o plano aponta para o arquivo dele em Documentos e planos.
#
#   * ligar na criação, trocar e desligar na edição;
#   * detalhe e relatório trazem o nome e a versão atual do arquivo;
#   * documento de outra escola: recusado (400, como na criação);
#   * documento apagado: o plano continua, sem o arquivo.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.planos_gestao')");
skip_all('clean.planos_gestao ausente (migration nao aplicada)') unless $has;

my $INEP  = '77777776';
my $OUTRA = '77777777';
my $EMAIL = sprintf 'planos.doc.%d@edumaps.test', $$;
my $SENHA = 'senha123';

my $limpar = sub {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escola_documentos WHERE cod_inep = ?', {}, $inep);
  }
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $INEP);
};
$limpar->();
END { return unless $has; $limpar->(); $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL) }
$dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
  {}, $INEP, "Escola Documento $INEP");

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestor Documento', email => $EMAIL, senha => $SENHA })->status_is(200);
my $token = $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })
  ->status_is(200)->tx->res->json->{token};
my $auth = { Authorization => "Bearer $token" };
my $base = "/api/gestor/$INEP/planos";
my ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

my $documento = sub ($inep, $nome, $versoes) {
  my ($doc) = $dbh->selectrow_array(
    'INSERT INTO clean.escola_documentos (cod_inep, gestor_id, nome) VALUES (?, ?, ?) RETURNING id',
    {}, $inep, $gid, $nome);
  $dbh->do(q{INSERT INTO clean.escola_documentos_versoes (documento_id, versao, caminho, nome_original, sha1)
             VALUES (?, ?, 'x/y', ?, repeat('b', 40))}, {}, $doc, $_, $nome) for 1 .. $versoes;
  return $doc;
};
my $ppp      = $documento->($INEP, 'PPP 2026.pdf', 3);
my $plano_pdf = $documento->($INEP, 'Plano de ação.pdf', 1);
my $alheio   = $documento->($OUTRA, 'Documento alheio.pdf', 1);

my $plano = $t->post_ok($base, $auth, json => { tipo => 'ppp', titulo => 'PPP 2026', documento_id => $ppp })
  ->status_is(201)->json_is('/documento_id' => $ppp)->tx->res->json->{id};

$t->get_ok("$base/$plano", $auth)->status_is(200)
  ->json_is('/documento' => { id => $ppp, nome => 'PPP 2026.pdf', versao_atual => 3 });

$t->put_ok("$base/$plano", $auth, json => { documento_id => $plano_pdf })->status_is(200)
  ->json_is('/documento/nome' => 'Plano de ação.pdf')->json_is('/documento/versao_atual' => 1);

$t->put_ok("$base/$plano", $auth, json => { documento_id => $alheio })->status_is(400)
  ->json_like('/error' => qr/Documento não encontrado nesta escola/);

$t->get_ok("$base/$plano/relatorio", $auth)->status_is(200)
  ->json_is('/plano/documento/nome' => 'Plano de ação.pdf');

$t->put_ok("$base/$plano", $auth, json => { documento_id => undef })->status_is(200)
  ->json_is('/documento_id' => undef)->json_is('/documento' => undef);

# documento apagado: o plano continua, sem o arquivo
$t->put_ok("$base/$plano", $auth, json => { documento_id => $ppp })->status_is(200);
$dbh->do('DELETE FROM clean.escola_documentos WHERE id = ?', {}, $ppp);
$t->get_ok("$base/$plano", $auth)->status_is(200)
  ->json_is('/titulo' => 'PPP 2026')->json_is('/documento_id' => undef)->json_is('/documento' => undef);

done_testing;
