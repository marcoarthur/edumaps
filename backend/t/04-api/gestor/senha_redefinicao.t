# t/04-api/gestor/senha_redefinicao.t
# "Esqueci minha senha" do gestor (#336):
#   GET  /api/gestor/senha/disponivel
#   POST /api/gestor/senha/esqueci     202 sempre (exista a conta ou não) · 409 · 429
#   POST /api/gestor/senha/redefinir   200 · 400 (token inválido/vencido/usado) · 429
# SMTP simulado (helper canais_smtp); o job `gestor_senha_email` roda por
# perform_jobs. Limites religados aqui (a suíte os desliga em Imports.pm).
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

delete $ENV{EDUMAPS_AUTH_LIMITE_OFF};

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
plan skip_all => 'clean.senha_redefinicoes ausente (migration nao aplicada)'
  unless $dbh->selectrow_array("SELECT to_regclass('clean.senha_redefinicoes')");

my @enviados;
$t->app->helper(canais_smtp => sub {
  sub ($cfg, $to, $from, $envelope) { push @enviados, { to => $to, envelope => $envelope }; { ok => 1 } };
});

my $minion = $t->app->minion;
# fila só deste teste: um worker de pé no mesmo banco não pega os jobs
my $FILA = "teste_senha_$$";
$t->app->config->{gestor_senha_fila} = $FILA;
my $pesq   = $t->app->model('Pesquisa');
my $cfgm   = $t->app->model('AppConfig');
my $secret = $t->app->secrets->[0];
my $INEP   = '99999997';
my $EMAIL  = sprintf 'redefine.%d@edumaps.test', $$;
my $SENHA  = 'antiga123';
my $NOVA   = 'novinha456';
my $BASE   = 'https://edumaps.teste.example';
my @chaves;

sub ip  { sprintf '198.51.100.%d', $_[0] }
sub hdr { { 'X-Real-IP' => $_[0] } }
sub chave { my ($e, $v) = @_; my $k = $pesq->auth_chave($secret, $v); push @chaves, [$e, $k]; $k }
sub esqueci {
  my ($email, $ip) = @_;
  chave(reset_email => $email); chave(reset_ip => $ip);
  $t->post_ok('/api/gestor/senha/esqueci', hdr($ip), json => { email => $email });
}
sub roda_jobs { $minion->perform_jobs_in_foreground({ queues => [$FILA] }) }
sub ultimo_token {
  my ($link) = $enviados[-1]{envelope} =~ m{(\Q$BASE\E/gestor/redefinir-senha#\S+)};
  my ($tok) = ($link // '') =~ /#([A-Za-z0-9_-]{43})$/;
  return $tok;
}

# config de e-mail ligada só durante o teste; restaura o que havia
my @CHAVES_CFG = qw(canais.email.enabled canais.email.smtp_host canais.email.from canais.email.public_base_url);
my %antes = map { $_->[0] => $_ } @{ $dbh->selectall_arrayref(
  'SELECT key, value, secret, sensitive, secret_key_version, updated_by, updated_at FROM app_config.items WHERE key = ANY(?)',
  {}, \@CHAVES_CFG) };

$dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?) ON CONFLICT (codigo_inep) DO NOTHING',
  {}, $INEP, 'Escola de teste da redefinição de senha');

END {
  return unless $dbh;
  $dbh->do('DELETE FROM clean.auth_falhas WHERE escopo = ? AND chave = ?', {}, @$_) for @chaves;
  $dbh->do(q{DELETE FROM clean.canal_mensagens WHERE canal = 'email' AND destinatario = ?}, {}, $EMAIL);
  $dbh->do('DELETE FROM clean.sessoes WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email = ?)', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $EMAIL);
  $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $INEP);
  $dbh->do('DELETE FROM minion_jobs WHERE queue = ?', {}, $FILA);
  $dbh->do('DELETE FROM app_config.items WHERE key = ANY(?)', {}, \@CHAVES_CFG);
  $dbh->do('INSERT INTO app_config.items (key, value, secret, sensitive, secret_key_version, updated_by, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)', {}, @$_) for values %antes;
}

subtest 'sem e-mail configurado: indisponível' => sub {
  $dbh->do('DELETE FROM app_config.items WHERE key = ANY(?)', {}, \@CHAVES_CFG);
  $t->get_ok('/api/gestor/senha/disponivel')->status_is(200)->json_is('/disponivel', 0);
  esqueci('qualquer@edumaps.test', ip(1))->status_is(409);
};

$cfgm->config_put('canais.email.enabled',         'true',                  'teste');
$cfgm->config_put('canais.email.smtp_host',       'smtp.teste.example',    'teste');
$cfgm->config_put('canais.email.from',            'nao-responda@teste.example', 'teste');
$cfgm->config_put('canais.email.public_base_url', $BASE,                   'teste');

# conta de teste
$t->post_ok('/api/gestor/pesquisas/perfil', hdr(ip(2)), json => {
  cod_inep => $INEP, nome => 'Gestora Redefine', email => $EMAIL, senha => $SENHA,
})->status_is(200);
chave(cadastro_ip => ip(2));
my $gid = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

subtest 'disponível com e-mail e URL pública' => sub {
  $t->get_ok('/api/gestor/senha/disponivel')->json_is('/disponivel', 1);
};

subtest 'pedido: mesma resposta exista a conta ou não' => sub {
  my $com = esqueci($EMAIL, ip(10))->status_is(202)->tx->res->json;
  my $sem = esqueci("ninguem.$$\@edumaps.test", ip(11))->status_is(202)->tx->res->json;
  is $sem, $com, 'corpo idêntico';

  my $jobs = $dbh->selectall_arrayref(q{SELECT args::text FROM minion_jobs WHERE queue = ? AND state = 'inactive'}, {}, $FILA);
  is scalar(@$jobs), 1, 'só a conta existente gera job';
  unlike $jobs->[0][0], qr/[A-Za-z0-9_-]{43}/, 'argumentos do job não levam token';

  esqueci('invalido', ip(12))->status_is(400);
};

subtest 'job: grava só o hash e envia o link' => sub {
  @enviados = ();
  roda_jobs();
  is scalar(@enviados), 1, 'um e-mail enviado';
  is $enviados[0]{to}, $EMAIL, 'para o gestor';
  my $tok = ultimo_token();
  ok $tok, 'e-mail traz o link com o token';
  like $enviados[0]{envelope}, qr/vale por 30 minutos/, 'avisa a validade';

  my $hash = $dbh->selectrow_array('SELECT token_hash FROM clean.senha_redefinicoes WHERE gestor_id = ? AND usado_em IS NULL', {}, $gid);
  isnt $hash, $tok, 'banco não guarda o token em claro';
  my $no_hist = $dbh->selectrow_array(q{SELECT count(*) FROM clean.canal_mensagens WHERE destinatario = ? AND corpo LIKE ?}, {}, $EMAIL, "%$tok%");
  is $no_hist, 0, 'histórico do canal não guarda o token';
};

subtest 'pedido novo invalida o anterior' => sub {
  my $velho = ultimo_token();
  esqueci($EMAIL, ip(13))->status_is(202);
  roda_jobs();
  my $novo = ultimo_token();
  isnt $novo, $velho, 'token novo';
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(14)), json => { token => $velho, senha => $NOVA })
    ->status_is(400)->json_like('/error', qr/não vale mais/);
};

subtest 'redefinir: senha nova, sessões encerradas, uso único' => sub {
  my $sessao = $t->post_ok('/api/gestor/login', hdr(ip(15)), json => { email => $EMAIL, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  chave(email => $EMAIL); chave(ip => ip(15));

  my $tok = ultimo_token();
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(16)), json => { token => $tok, senha => $NOVA })
    ->status_is(200)->json_is('/ok', 1);

  $t->get_ok('/api/gestor/me', { Authorization => "Bearer $sessao" })->status_is(401, 'sessão antiga encerrada');
  $t->post_ok('/api/gestor/login', hdr(ip(17)), json => { email => $EMAIL, senha => $SENHA })->status_is(401, 'senha antiga não entra');
  $t->post_ok('/api/gestor/login', hdr(ip(17)), json => { email => $EMAIL, senha => $NOVA })->status_is(200, 'senha nova entra');
  chave(ip => ip(17));
  like $dbh->selectrow_array('SELECT senha_hash FROM clean.gestores WHERE id = ?', {}, $gid), qr/^\$argon2id\$/, 'gravada em Argon2id';

  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(18)), json => { token => $tok, senha => 'outra789' })
    ->status_is(400, 'token não serve duas vezes');
};

subtest 'token vencido' => sub {
  esqueci($EMAIL, ip(19))->status_is(202);
  roda_jobs();
  my $tok = ultimo_token();
  $dbh->do(q{UPDATE clean.senha_redefinicoes SET expira_em = now() - interval '1 minute' WHERE gestor_id = ? AND usado_em IS NULL}, {}, $gid);
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(20)), json => { token => $tok, senha => 'outra789' })->status_is(400);
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(20)), json => { token => 'x' x 43, senha => 'curta' })
    ->status_is(400, 'token inexistente responde igual');
};

subtest 'limites' => sub {
  # 3 pedidos por e-mail por hora (já houve 3 neste e-mail, de IPs diferentes)
  esqueci($EMAIL, ip(30))->status_is(429)->header_like('Retry-After', qr/^\d+$/);
  # 10 tentativas por IP: tokens inválidos em /redefinir também contam
  chave(reset_ip => ip(31));
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(31)), json => { token => 'y' x 43, senha => 'qualquer1' })->status_is(400) for 1 .. 10;
  $t->post_ok('/api/gestor/senha/redefinir', hdr(ip(31)), json => { token => 'y' x 43, senha => 'qualquer1' })->status_is(429);
};

done_testing();
