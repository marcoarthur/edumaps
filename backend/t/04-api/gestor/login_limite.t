# t/04-api/gestor/login_limite.t
# Limite de tentativas de login e de cadastro do gestor (#335).
# Religa os limites (a suíte os desliga em t/lib/Imports.pm) com valores
# pequenos; cada subteste usa um IP próprio (X-Real-IP, aceito porque o
# Test::Mojo conecta de 127.0.0.1, um proxy confiável).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

delete $ENV{EDUMAPS_AUTH_LIMITE_OFF};

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'clean.auth_falhas ausente (migration nao aplicada)'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.auth_falhas')");

$t->app->config->{auth_limite} = {
  login_email => { max => 3, janela => 900 },
  login_ip    => { max => 5, janela => 900 },
  cadastro_ip => { max => 4, janela => 3600 },
};

my $model  = $t->app->model('Pesquisa');
my $secret = $t->app->secrets->[0];
my $INEP   = '99999998';
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'limite.%d@edumaps.test', $$;
my @chaves;   # [escopo, chave] criados aqui, para limpar no fim

sub ip   { sprintf '198.51.100.%d', $_[0] }
sub hdr  { { 'X-Real-IP' => $_[0] } }
sub chave {
  my ($escopo, $valor) = @_;
  my $k = $model->auth_chave($secret, $valor);
  push @chaves, [$escopo, $k];
  return $k;
}
sub login {
  my ($email, $senha, $ip) = @_;
  chave(email => $email); chave(ip => $ip);
  return $t->post_ok('/api/gestor/login', hdr($ip), json => { email => $email, senha => $senha });
}

$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?) ON CONFLICT (codigo_inep) DO NOTHING',
  {}, $INEP, 'Escola de teste do limite de login');

END {
  return unless $dbh;
  $dbh->do('DELETE FROM clean.auth_falhas WHERE escopo = ? AND chave = ?', {}, @$_) for @chaves;
  $dbh->do('DELETE FROM clean.sessoes WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
}

# conta de teste (cadastro de um IP só dele)
chave(cadastro_ip => ip(1));
$t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip(1)), json => {
  cod_inep => $INEP, nome => 'Gestor Limite', email => $EMAIL, senha => $SENHA,
})->status_is(200);

subtest 'e-mail: 3 falhas bloqueiam, até a senha certa' => sub {
  login($EMAIL, 'errada99', ip(10))->status_is(401) for 1 .. 3;

  login($EMAIL, 'errada99', ip(11))->status_is(429)
    ->json_like('/error', qr/^Muitas tentativas\. Tente de novo em \d+ minutos?\.$/)
    ->header_like('Retry-After', qr/^\d+$/);
  my $ra = $t->tx->res->headers->header('Retry-After');
  ok $ra > 0 && $ra <= 900, "Retry-After dentro da janela ($ra s)";

  # senha certa durante o bloqueio também é recusada (senão o bloqueio é inútil)
  login($EMAIL, $SENHA, ip(12))->status_is(429);
};

subtest 'janela passou: volta a entrar e o acerto zera o e-mail' => sub {
  my $k = $model->auth_chave($secret, $EMAIL);
  $dbh->do(q{UPDATE clean.auth_falhas SET criado_em = now() - interval '16 minutes'
              WHERE escopo = 'email' AND chave = ?}, {}, $k);

  login($EMAIL, $SENHA, ip(13))->status_is(200)->json_has('/token');
  is $dbh->selectrow_array(q{SELECT count(*) FROM clean.auth_falhas WHERE escopo = 'email' AND chave = ?}, {}, $k),
    0, 'acerto apaga as falhas do e-mail';

  # contagem recomeçou: 2 falhas ainda não bloqueiam
  login($EMAIL, 'errada99', ip(13))->status_is(401) for 1 .. 2;
  login($EMAIL, $SENHA, ip(13))->status_is(200);
};

subtest 'IP: e-mails diferentes do mesmo IP somam' => sub {
  login("ninguem$_.$$\@edumaps.test", 'errada99', ip(20))->status_is(401) for 1 .. 5;
  login("outro.$$\@edumaps.test", 'errada99', ip(20))->status_is(429);
  # outro IP segue livre
  login("outro.$$\@edumaps.test", 'errada99', ip(21))->status_is(401);
};

subtest 'e-mail sem conta: mesmas respostas (não revela existência)' => sub {
  my $fantasma = "fantasma.$$\@edumaps.test";
  login($fantasma, 'errada99', ip(30 + $_))->status_is(401)->json_is('/error', 'E-mail ou senha inválidos') for 1 .. 3;
  login($fantasma, 'errada99', ip(34))->status_is(429);
};

subtest 'cadastro: limite por IP' => sub {
  chave(cadastro_ip => ip(40));
  # e-mail existente: 409 conta como tentativa
  $t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip(40)), json => {
    cod_inep => $INEP, nome => 'Sonda', email => $EMAIL, senha => 'qualquer1',
  })->status_is(409) for 1 .. 4;
  $t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip(40)), json => {
    cod_inep => $INEP, nome => 'Sonda', email => $EMAIL, senha => 'qualquer1',
  })->status_is(429)->header_like('Retry-After', qr/^\d+$/);
};

subtest 'proxies_confiaveis do config restringe quem pode mandar X-Real-IP' => sub {
  # Test::Mojo conecta de 127.0.0.1: fora da lista → o cabeçalho é ignorado e
  # todos os pedidos contam no IP da conexão, não no forjado.
  local $t->app->config->{auth_limite}{proxies_confiaveis} = ['10.9.9.9/32'];
  my $k127 = chave(cadastro_ip => '127.0.0.1');
  $dbh->do(q{DELETE FROM clean.auth_falhas WHERE escopo = 'cadastro_ip' AND chave = ?}, {}, $k127);
  for my $n (50 .. 53) {
    $t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip($n)), json => {
      cod_inep => $INEP, nome => 'Sonda', email => $EMAIL, senha => 'qualquer1',
    })->status_is(409);
  }
  $t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip(54)), json => {
    cod_inep => $INEP, nome => 'Sonda', email => $EMAIL, senha => 'qualquer1',
  })->status_is(429, 'IPs forjados diferentes não escapam do limite');
};

subtest 'tabela não guarda e-mail nem IP em claro' => sub {
  my $claro = $dbh->selectrow_array(
    'SELECT count(*) FROM clean.auth_falhas WHERE chave LIKE ? OR chave LIKE ?', {}, '%@%', '198.51.%');
  is $claro, 0, 'só HMAC na coluna chave';
};

done_testing();
