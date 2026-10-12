# t/04-api/admin/consentimento.t
# Consentimento versionado — admin (#214, onda 1 — contrato congelado):
#   GET  /api/admin/consentimento/versoes               200 [ {id, versao, texto, texto_hash, status, publicada_em, created_at} ]
#   POST /api/admin/consentimento/versoes               201 · 400 · 409
#   PUT  /api/admin/consentimento/versoes/:id           200 · 400 · 404 · 409
#   POST /api/admin/consentimento/versoes/:id/publicar  200 · 404 · 409
# Auth 401/403. Restaura a versão vigente original no fim.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use Encode ();
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.consentimento_versoes')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $INEP_ADMIN  = '77777772';
my $INEP_USER   = '66666662';
my $ADMIN_EMAIL = sprintf('admin.consent.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.consent.%d@edumaps.test', $$);
my $SENHA = 'senha123';
my $V     = "a$$";
my ($admin, $user, $vigente_original);

END {
  return unless $has;
  $dbh->do(q{DELETE FROM clean.consentimento_versoes WHERE versao LIKE ?}, {}, "$V%");
  $dbh->do(q{UPDATE clean.consentimento_versoes SET status = 'vigente' WHERE id = ?},
           {}, $vigente_original) if $vigente_original;
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep IN (?, ?)', {}, $INEP_ADMIN, $INEP_USER);
}

sub H { return { Authorization => "Bearer $admin" } }
my $BASE = '/api/admin/consentimento/versoes';

subtest 'setup' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  ($vigente_original) = $dbh->selectrow_array(
    q{SELECT id FROM clean.consentimento_versoes WHERE status = 'vigente'});
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING', {}, $inep, 'Escola teste consentimento');
  }
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin', email => $ADMIN_EMAIL, senha => $SENHA })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Comum', email => $USER_EMAIL, senha => $SENHA })->status_is(200);
  $dbh->do(q{UPDATE clean.gestores SET access_role = 'admin' WHERE email = ?}, {}, $ADMIN_EMAIL);
  $admin = $t->post_ok('/api/gestor/login', json => { email => $ADMIN_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  $user = $t->post_ok('/api/gestor/login', json => { email => $USER_EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  ok $admin && $user, 'tokens';
};

subtest 'auth: 401 sem token, 403 gestor comum' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;
  my $U = { Authorization => "Bearer $user" };
  $t->get_ok($BASE)->status_is(401);
  $t->post_ok($BASE, json => { versao => "${V}x", texto => 'x' })->status_is(401);
  $t->put_ok("$BASE/1", json => { texto => 'x' })->status_is(401);
  $t->post_ok("$BASE/1/publicar")->status_is(401);
  $t->get_ok($BASE, $U)->status_is(403);
  $t->post_ok($BASE, $U, json => { versao => "${V}x", texto => 'x' })->status_is(403);
  $t->put_ok("$BASE/1", $U, json => { texto => 'x' })->status_is(403);
  $t->post_ok("$BASE/1/publicar", $U)->status_is(403);
};

subtest 'listar, criar, editar, publicar' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has;

  my $lista = $t->get_ok($BASE, H())->status_is(200)->tx->res->json;
  ok ref $lista eq 'ARRAY' && @$lista, 'lista não vazia (seed)';
  is [sort keys %{ $lista->[0] }],
     [qw(created_at id publicada_em status texto texto_hash versao)], 'campos do contrato';
  ok scalar(grep { $_->{status} eq 'vigente' } @$lista) == 1, 'uma vigente';

  $t->post_ok($BASE, H(), json => { versao => '', texto => 'x' })->status_is(400)->json_has('/error');
  $t->post_ok($BASE, H(), json => { versao => "${V}1" })->status_is(400)->json_has('/error');
  $t->post_ok($BASE, H(), 'não-json')->status_is(400);

  my $r = $t->post_ok($BASE, H(), json => { versao => "${V}1", texto => "# Termo\n\nTexto ção." })
    ->status_is(201)->json_is('/status', 'rascunho')->json_is('/publicada_em', undef)
    ->tx->res->json;
  is $r->{texto_hash}, sha256_hex(Encode::encode_utf8("# Termo\n\nTexto ção.")), 'hash';
  $t->post_ok($BASE, H(), json => { versao => "${V}1", texto => 'x' })
    ->status_is(409, 'versão repetida');
  is $dbh->selectrow_array(q{SELECT criado_por FROM clean.consentimento_versoes WHERE id = ?},
                           {}, $r->{id}),
     $dbh->selectrow_array(q{SELECT id FROM clean.gestores WHERE email = ?}, {}, $ADMIN_EMAIL),
     'criado_por = admin';

  $t->put_ok("$BASE/$r->{id}", H(), json => { texto => 'Novo texto' })->status_is(200)
    ->json_is('/texto', 'Novo texto')->json_is('/texto_hash', sha256_hex('Novo texto'));
  $t->put_ok("$BASE/$r->{id}", H(), json => {})->status_is(400);
  $t->put_ok("$BASE/999999999", H(), json => { texto => 'x' })->status_is(404);
  $t->post_ok("$BASE/999999999/publicar", H())->status_is(404);

  $t->post_ok("$BASE/$r->{id}/publicar", H())->status_is(200)
    ->json_is('/status', 'vigente')->json_has('/publicada_em');
  $t->get_ok('/api/canais/consentimento')->status_is(200)
    ->json_is('/versao', "${V}1")->json_is('/texto', 'Novo texto');
  is $dbh->selectrow_array(q{SELECT status FROM clean.consentimento_versoes WHERE id = ?},
                           {}, $vigente_original), 'arquivada', 'anterior arquivada';

  $t->post_ok("$BASE/$r->{id}/publicar", H())->status_is(409, 'já publicada');
  $t->put_ok("$BASE/$r->{id}", H(), json => { texto => 'mudar' })->status_is(409, 'imutável');
  $t->put_ok("$BASE/$vigente_original", H(), json => { texto => 'mudar' })
    ->status_is(409, 'arquivada imutável');
};

done_testing;
