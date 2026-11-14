# t/04-api/gestor/idempotencia.t
# #416: o POST autenticado com Idempotency-Key não cria duas vezes.
#
#   * mesma chave duas vezes: um registro só, e a mesma resposta (replay);
#   * chaves diferentes: dois registros, mesmo com o mesmo conteúdo;
#   * a chave é da conta: outra conta com a mesma chave é independente;
#   * a mesma chave com outra rota ou outro corpo: 422;
#   * chave em andamento: 409;
#   * pedido que falha não guarda a chave: a nova tentativa cria;
#   * chave vencida: cria de novo; sem o cabeçalho, nada muda.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use Mojo::JSON qw(encode_json);
use Digest::SHA qw(sha256_hex);
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
skip_all('clean.idempotencia ausente (migration nao aplicada)')
  unless $dbh->selectrow_array("SELECT to_regclass('clean.idempotencia')")
     and $dbh->selectrow_array("SELECT to_regclass('clean.planos_gestao')");

my $INEP   = '77777771';
my $OUTRA  = '66666671';
my $SENHA  = 'senha123';
my $EMAIL  = sprintf 'idem.a.%d@edumaps.test', $$;
my $OEMAIL = sprintf 'idem.b.%d@edumaps.test', $$;
my ($token, $out_token);

for my $inep ($INEP, $OUTRA) {
  $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  $dbh->do('INSERT INTO clean.censo_escolas (nu_ano_censo, co_entidade, no_entidade) VALUES (2025, ?, ?)',
    {}, $inep, "Escola Idem $inep");
}

END {
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.planos_gestao WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ? AND nu_ano_censo = 2025', {}, $inep);
  }
  $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $_) for $EMAIL, $OEMAIL;
}

for my $g ([ $INEP, $EMAIL, \$token ], [ $OUTRA, $OEMAIL, \$out_token ]) {
  my ($inep, $email, $ref) = @$g;
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $inep, nome => "Gestor $inep", email => $email, senha => $SENHA,
  })->status_is(200);
  $$ref = $t->post_ok('/api/gestor/login', json => { email => $email, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
}
my ($gestor_id) = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $EMAIL);

my $base = "/api/gestor/$INEP/planos";
my $cab  = sub ($chave, $tok = $token) {
  { Authorization => "Bearer $tok", ($chave ? ('Idempotency-Key' => $chave) : ()) }
};
my $planos = sub ($titulo) {
  $dbh->selectrow_array('SELECT count(*) FROM clean.planos_gestao WHERE cod_inep = ? AND titulo = ?',
    {}, $INEP, $titulo);
};
my $plano = { tipo => 'acao', titulo => 'Plano idem' };

subtest 'mesma chave duas vezes: cria uma vez e repete a resposta' => sub {
  my $r1 = $t->post_ok($base, $cab->('chave-0001'), json => $plano)->status_is(201)
    ->header_isnt('Idempotent-Replayed' => 'true')->tx->res->json;
  my $r2 = $t->post_ok($base, $cab->('chave-0001'), json => $plano)->status_is(201)
    ->header_is('Idempotent-Replayed' => 'true')->tx->res->json;
  is $r2, $r1, 'a mesma resposta (mesmo id)';
  is $planos->('Plano idem'), 1, 'um plano só';
};

subtest 'chaves diferentes: dois registros, mesmo com o mesmo conteúdo' => sub {
  my $p = { tipo => 'acao', titulo => 'Plano duas chaves' };
  $t->post_ok($base, $cab->('chave-0002'), json => $p)->status_is(201);
  $t->post_ok($base, $cab->('chave-0003'), json => $p)->status_is(201);
  is $planos->('Plano duas chaves'), 2, 'dois planos';
};

subtest 'sem o cabeçalho, nada muda' => sub {
  my $p = { tipo => 'acao', titulo => 'Plano sem chave' };
  $t->post_ok($base, $cab->(undef), json => $p)->status_is(201) for 1, 2;
  is $planos->('Plano sem chave'), 2, 'cada POST cria';
};

subtest 'a chave é da conta' => sub {
  my $p = { tipo => 'acao', titulo => 'Plano da outra' };
  $t->post_ok("/api/gestor/$OUTRA/planos", $cab->('chave-0001', $out_token), json => $p)
    ->status_is(201)->header_isnt('Idempotent-Replayed' => 'true');
};

subtest 'a mesma chave com outra rota ou outro corpo: 422' => sub {
  $t->post_ok($base, $cab->('chave-0001'), json => { tipo => 'acao', titulo => 'Outro título' })
    ->status_is(422)->json_like('/error' => qr/outros dados/);
  is $planos->('Outro título'), 0, 'não criou';
  my ($pid) = $dbh->selectrow_array('SELECT id FROM clean.planos_gestao WHERE cod_inep = ? AND titulo = ?',
    {}, $INEP, 'Plano idem');
  $t->post_ok("$base/$pid/objetivos", $cab->('chave-0001'), json => $plano)->status_is(422);
};

subtest 'chave em andamento: 409' => sub {
  # o mesmo hash que o servidor calcula do corpo JSON do pedido
  $dbh->do(q{INSERT INTO clean.idempotencia (gestor_id, chave, rota, corpo_hash)
             VALUES (?, 'chave-andamento', ?, ?)}, {}, $gestor_id, "POST $base",
           sha256_hex(encode_json($plano)));
  $t->post_ok($base, $cab->('chave-andamento'), json => $plano)->status_is(409)
    ->json_like('/error' => qr/sendo processado/);
  # abandonado (mais de 2 min): conta como livre
  $dbh->do(q{UPDATE clean.idempotencia SET criado_em = NOW() - interval '3 minutes'
              WHERE gestor_id = ? AND chave = 'chave-andamento'}, {}, $gestor_id);
  $t->post_ok($base, $cab->('chave-andamento'), json => { tipo => 'acao', titulo => 'Plano retomado' })
    ->status_is(201);
  is $planos->('Plano retomado'), 1, 'criou depois do abandono';
};

subtest 'pedido que falha não guarda a chave' => sub {
  $t->post_ok($base, $cab->('chave-erro-01'), json => { titulo => 'Sem tipo' })->status_is(400);
  ok !$dbh->selectrow_array(q{SELECT 1 FROM clean.idempotencia WHERE gestor_id = ? AND chave = 'chave-erro-01'},
    {}, $gestor_id), 'chave apagada';
  $t->post_ok($base, $cab->('chave-erro-01'), json => { tipo => 'acao', titulo => 'Plano corrigido' })
    ->status_is(201);
  is $planos->('Plano corrigido'), 1, 'a nova tentativa cria';
};

subtest 'chave vencida: cria de novo' => sub {
  $dbh->do(q{UPDATE clean.idempotencia SET criado_em = NOW() - interval '11 minutes'
              WHERE gestor_id = ? AND chave = 'chave-0001'}, {}, $gestor_id);
  $t->post_ok($base, $cab->('chave-0001'), json => $plano)->status_is(201)
    ->header_isnt('Idempotent-Replayed' => 'true');
  is $planos->('Plano idem'), 2, 'depois da validade, é um envio novo';
};

subtest 'chave fora do formato: 400' => sub {
  $t->post_ok($base, $cab->('curta'), json => $plano)->status_is(400);
  $t->post_ok($base, $cab->('com espaço e ç'), json => $plano)->status_is(400);
};

subtest 'resposta com acento volta igual no replay' => sub {
  my $p = { tipo => 'acao', titulo => 'Plano de ação — São João' };
  my $r1 = $t->post_ok($base, $cab->('chave-acento'), json => $p)->status_is(201)->tx->res->json;
  my $r2 = $t->post_ok($base, $cab->('chave-acento'), json => $p)->status_is(201)
    ->header_is('Idempotent-Replayed' => 'true')->tx->res->json;
  is $r2->{titulo}, 'Plano de ação — São João', 'texto intacto';
  is $r2, $r1, 'mesma resposta';
};

done_testing;
