# t/04-api/admin/config.t
# Testes da API do Painel de Configuração (/api/admin/config/*):
#   auth (401 sem token, 403 gestor comum, 200 admin), árvore, show com
#   máscara de segredo, PUT grava cifrado, validate sem gravar. Só roda onde
#   app_config e gestor_access_role foram aplicadas.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('app_config.items')")
  && $dbh->selectrow_array(
  "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $INEP_ADMIN = '99999999';
my $INEP_USER  = '88888888';
my $ADMIN_EMAIL = sprintf('admin.config.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.config.%d@edumaps.test', $$);
my $CPF_ADMIN   = sprintf('5111111%04d', $$ % 10000);
my $CPF_USER    = sprintf('5222222%04d', $$ % 10000);
my $SENHA = 'senha123';

my ($admin_token, $user_token);

END {
  return if !$has_tables;
  $dbh->do('DELETE FROM app_config.items WHERE key LIKE $1', {}, 'integrations.assistant_censo.%');
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'setup: escolas + gestores (admin e comum)' => sub {
  plan skip_all => 'app_config.items/galeria access_role ausente (migrations nao aplicadas)'
    unless $has_tables;

  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste da API admin');
  }

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin Config', email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'Gestor Comum', email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200);

  # promove o primeiro a admin (gestor_access_role)
  my $admin_id = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $ADMIN_EMAIL);
  $dbh->do('UPDATE clean.gestores SET access_role = ? WHERE id = ?', {}, 'admin', $admin_id);

  $admin_token = $t->post_ok('/api/gestor/login', json => {
    email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};
  $user_token = $t->post_ok('/api/gestor/login', json => {
    email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200)->tx->res->json->{token};

  my $me = $t->get_ok('/api/gestor/me', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;
  is $me->{access_role}, 'admin', '/api/gestor/me expõe access_role do admin';
};

subtest 'auth: 401 sem token, 403 para gestor comum' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->get_ok('/api/admin/config/tree')->status_is(401);
  $t->get_ok('/api/admin/config/integrations.assistant_censo.api_key')->status_is(401);
  $t->put_ok('/api/admin/config/integrations.assistant_censo.api_key', json => { value => 'x' })
    ->status_is(401);

  $t->get_ok('/api/admin/config/tree', { Authorization => "Bearer $user_token" })
    ->status_is(403)->json_has('/error');
  $t->get_ok('/api/admin/config/integrations.assistant_censo.api_key',
    { Authorization => "Bearer $user_token" })->status_is(403);
};

subtest 'tree: categorias e folha chaves' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $tree = $t->get_ok('/api/admin/config/tree', { Authorization => "Bearer $admin_token" })
    ->status_is(200)->tx->res->json;
  my @labels = map { $_->{label} } @{ $tree->{categories} };
  is join(',', @labels), 'Sistema,Integrações,Aparência,Comportamento,Outros', 'categorias';

  my ($integ) = grep { $_->{key} eq 'integracoes' } @{ $tree->{categories} };
  my ($assistente) = grep { $_->{key} eq 'assistant_censo' } @{ $integ->{children} };
  my ($chaves) = grep { $_->{key} eq 'integrations.assistant_censo.api_key' } @{ $assistente->{children} };
  ok $chaves && !$chaves->{value}{set}, 'chaves ainda não definida';

  $t->get_ok('/api/admin/config/foo.bar', { Authorization => "Bearer $admin_token" })
    ->status_is(404)->json_has('/error');
};

subtest 'show: segredo mascarado, valor não-sensível em claro' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $chaves = $t->get_ok('/api/admin/config/integrations.assistant_censo.api_key',
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->json;
  is $chaves->{type}, 'secret', 'type secret';
  is $chaves->{value}{set}, 0, 'set=0 sem valor';
  ok !exists $chaves->{value}{plaintext}, 'sem plaintext';
};

subtest 'put: grava valor cifrado e valida' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY} = 'chave-mestra-de-teste-12345';

  # validação de formato (não grava): valor curto -> 400
  $t->post_ok('/api/admin/config/integrations.assistant_censo.api_key/validate',
    { Authorization => "Bearer $admin_token" }, json => { value => 'curta' })
    ->status_is(400)->json_has('/error');

  # validação ok -> { ok: 1 }
  $t->post_ok('/api/admin/config/integrations.assistant_censo.api_key/validate',
    { Authorization => "Bearer $admin_token" }, json => { value => 'sk-muito-longa-123456' })
    ->status_is(200)->json_is('/ok' => 1);

  # PUT grava e mascarado na resposta
  my $saved = $t->put_ok('/api/admin/config/integrations.assistant_censo.api_key',
    { Authorization => "Bearer $admin_token" }, json => { value => 'sk-teste-1234567890' })
    ->status_is(200)->tx->res->json;
  is $saved->{value}{set}, 1, 'set=1 depois de gravar';
  ok !exists $saved->{value}{plaintext}, 'resposta sem plaintext';

  # PUT em campo numérico com valor inválido -> 400
  $t->put_ok('/api/admin/config/behavior.default_ano',
    { Authorization => "Bearer $admin_token" }, json => { value => 'abc' })
    ->status_is(400)->json_has('/error');

  # texto não-sensível vai em claro
  $t->put_ok('/api/admin/config/behavior.default_ano',
    { Authorization => "Bearer $admin_token" }, json => { value => '2025' })
    ->status_is(200)->json_is('/value' => 2025);
  my $ano = $t->get_ok('/api/admin/config/behavior.default_ano',
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->json;
  is $ano->{value}, 2025, 'GET devolve o valor numérico em claro';

  # no banco: secret está cifrado (hex != plaintext), value em jsonb
  my $row = $dbh->selectrow_hashref(
    'SELECT ENCODE(secret, \'hex\') AS secret, value, sensitive FROM app_config.items WHERE key = ?',
    {}, 'integrations.assistant_censo.api_key');
  ok $row->{sensitive} && length($row->{secret} // '') > 0, 'secret cifrado no banco';
  ok index($row->{secret}, 'sk-teste-1234567890') == -1, 'plaintext não gravado em claro';
};

subtest 'put: erro amigável se master key ausente' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;
  local $ENV{EDUMAPS_CONFIG_MASTER_KEY};
  delete $ENV{EDUMAPS_CONFIG_MASTER_KEY};

  $t->put_ok('/api/admin/config/integrations.assistant_censo.api_key',
    { Authorization => "Bearer $admin_token" }, json => { value => 'sk-teste-1234567890' })
    ->status_is(500)->json_has('/error');
};

done_testing;