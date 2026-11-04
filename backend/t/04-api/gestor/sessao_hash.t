# t/04-api/gestor/sessao_hash.t
# Sessão do gestor: o banco guarda só o SHA-256 do token bearer. O token em
# claro vai ao cliente no login e nunca aparece em clean.sessoes.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Digest::SHA qw(sha256_hex);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'clean.sessoes.token_hash ausente (migration nao aplicada)'
  unless $dbh->selectrow_array(q{SELECT 1 FROM pg_attribute
    WHERE attrelid = to_regclass('clean.sessoes') AND attname = 'token_hash' AND NOT attisdropped});

my $INEP  = '99999997';
my $SENHA = 'senha123';
my $EMAIL = sprintf 'sessao.hash.%d@edumaps.test', $$;

$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?) ON CONFLICT (codigo_inep) DO NOTHING',
  {}, $INEP, 'Escola de teste da sessão');

END {
  return unless $dbh;
  $dbh->do('DELETE FROM clean.sessoes WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
}

$t->post_ok('/api/gestor/pesquisas/perfil', json => {
  cod_inep => $INEP, nome => 'Gestora Sessão', email => $EMAIL, senha => $SENHA,
})->status_is(200);
my ($gid) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

sub login {
  $t->post_ok('/api/gestor/login', json => { email => $EMAIL, senha => $SENHA })->status_is(200);
  return $t->tx->res->json->{token};
}
sub bearer { { Authorization => "Bearer $_[0]" } }
sub hashes { $dbh->selectcol_arrayref('SELECT token_hash FROM clean.sessoes WHERE gestor_id = ?', {}, $gid) }

subtest 'login devolve o token; o banco guarda só o hash' => sub {
  my $token = login();
  like $token, qr/^[0-9a-f]{64}$/, 'token de 32 bytes em hex';
  my $h = hashes();
  is scalar(@$h), 1, 'uma sessão';
  is $h->[0], sha256_hex($token), 'banco tem o SHA-256 do token';
  isnt $h->[0], $token, 'e não o token';
  is $dbh->selectrow_array('SELECT count(*) FROM clean.sessoes WHERE token_hash = ?', {}, $token), 0,
    'buscar pelo token em claro não acha nada';

  $t->get_ok('/api/gestor/me', bearer($token))->status_is(200)->json_is('/email', $EMAIL);
};

subtest 'o hash não serve de bearer' => sub {
  my ($h) = @{ hashes() };
  $t->get_ok('/api/gestor/me', bearer($h))->status_is(401);
};

subtest 'logout apaga a sessão pelo hash' => sub {
  my $token = login();
  my $antes = scalar @{ hashes() };
  $t->post_ok('/api/gestor/logout', bearer($token))->status_is(204);
  is scalar(@{ hashes() }), $antes - 1, 'sessão removida';
  $t->get_ok('/api/gestor/me', bearer($token))->status_is(401);
};

subtest 'sessão antiga (uuid convertido pela migration) segue válida' => sub {
  # mesmo cálculo da migration sessoes_token_hash: sha256 do texto do uuid
  my $uuid = $dbh->selectrow_array('SELECT gen_random_uuid()::text');
  $dbh->do(q{INSERT INTO clean.sessoes (gestor_id, token_hash, expires_at)
             VALUES (?, encode(sha256(convert_to(?, 'UTF8')), 'hex'), NOW() + interval '1 day')},
    {}, $gid, $uuid);
  $t->get_ok('/api/gestor/me', bearer($uuid))->status_is(200)->json_is('/email', $EMAIL);
};

subtest 'banco recusa token em claro fora do formato' => sub {
  my $ok = eval {
    local $dbh->{PrintError} = 0; local $dbh->{RaiseError} = 1;
    $dbh->do(q{INSERT INTO clean.sessoes (gestor_id, token_hash, expires_at)
               VALUES (?, 'nao-e-hash', NOW())}, {}, $gid);
    1;
  };
  ok !$ok, 'CHECK de formato barra valor que não é SHA-256 hex';
};

done_testing;
