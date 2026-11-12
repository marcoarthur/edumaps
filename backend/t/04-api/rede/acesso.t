# t/04-api/rede/acesso.t
# #394 (visão da rede, #375): papel de rede, conta por convite e autorização.
#
#   * admin cria a conta (409 e-mail repetido; 403 para quem não é admin);
#   * convite: válido, substituído por um novo, usado, vencido; a senha só
#     existe depois do convite;
#   * vínculo: conceder (409 repetido; 400 federal/privada ou município
#     inexistente), revogar corta o acesso na hora;
#   * escolas da rede pela linha MAIS RECENTE do Censo (dependência e
#     município), só em atividade na lista;
#   * conta de rede não entra nas rotas do gestor; gestor e admin não entram
#     nas rotas da rede; auditoria de tudo.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $dbh = $t->app->schema->storage->dbh;
my $has = $dbh->selectrow_array("SELECT to_regclass('clean.rede_vinculos')");
skip_all('clean.rede_vinculos ausente (migration nao aplicada)') unless $has;

my $P   = sprintf '%04d', $$ % 10000;
my $M1  = 9990001;           # municípios fictícios
my $M2  = 9990002;
my %E   = (A => 77778801, B => 77778802, C => 77778803, D => 77778804, E => 77778805, F => 77778806);
my $ADMIN = "admin.rede.$P\@edumaps.test";
my $GEST  = "gestor.rede.$P\@edumaps.test";
my $REDE  = "tecnica.rede.$P\@edumaps.test";

sub limpa {
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?, ?)', {}, $ADMIN, $GEST, $REDE);
  $dbh->do('DELETE FROM clean.censo_escolas WHERE co_entidade = ANY(?)', {}, [ values %E ]);
}
limpa();
END { limpa() if $has }

# Censo: (inep, ano, dependência, município, situação)
my $censo = $dbh->prepare(q{INSERT INTO clean.censo_escolas
  (nu_ano_censo, co_entidade, no_entidade, tp_dependencia, co_municipio, no_municipio, sg_uf, tp_situacao_funcionamento)
  VALUES (?, ?, ?, ?, ?, ?, 'ZZ', ?)});
$censo->execute(2025, $E{A}, 'Escola A municipal', 3, $M1, 'Vila Um', 1);
$censo->execute(2025, $E{B}, 'Escola B estadual',  2, $M1, 'Vila Um', 1);
$censo->execute(2025, $E{C}, 'Escola C outro município', 3, $M2, 'Vila Dois', 1);
$censo->execute(2024, $E{D}, 'Escola D estadualizada', 3, $M1, 'Vila Um', 1);
$censo->execute(2025, $E{D}, 'Escola D estadualizada', 2, $M1, 'Vila Um', 1);
$censo->execute(2025, $E{E}, 'Escola E paralisada', 3, $M1, 'Vila Um', 2);
$censo->execute(2025, $E{F}, 'Escola F privada',    4, $M1, 'Vila Um', 1);

# admin e gestor de escola
for ([$ADMIN, 'Admin'], [$GEST, 'Gestora A']) {
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $E{A}, nome => $_->[1], email => $_->[0], senha => 'senha123' })->status_is(200);
}
$dbh->do(q{UPDATE clean.gestores SET access_role = 'admin' WHERE email = ?}, {}, $ADMIN);
my $tok = sub ($email, $senha = 'senha123') {
  $t->post_ok('/api/gestor/login', json => { email => $email, senha => $senha })->tx->res->json->{token};
};
my $H = sub ($token) { { Authorization => "Bearer $token" } };
my $admin  = $tok->($ADMIN);
my $gestor = $tok->($GEST);
my $base = '/api/admin/rede/contas';
my ($conta, $convite1, $rede);

subtest 'admin cria a conta de rede com convite' => sub {
  $t->post_ok($base, $H->($gestor), json => { nome => 'X', email => $REDE })->status_is(403);
  $t->post_ok($base, $H->($admin), json => { nome => '', email => 'nao-e-email' })->status_is(400)
    ->json_has('/campos/nome')->json_has('/campos/email');
  my $r = $t->post_ok($base, $H->($admin), json => { nome => 'Técnica da Rede', email => $REDE, cargo => 'Técnica pedagógica' })
    ->status_is(201)->json_is('/conta/senha_definida' => Mojo::JSON::false)
    ->json_is('/conta/cargo' => 'Técnica pedagógica')->json_is('/conta/vinculos' => [])
    ->tx->res->json;
  $conta = $r->{conta}{id};
  $convite1 = $r->{convite}{token};
  like $convite1, qr/^[A-Za-z0-9_-]{43}$/, 'token do convite';
  is $dbh->selectrow_array('SELECT count(*) FROM clean.rede_convites WHERE token_hash = ?', {}, $convite1), 0,
    'o banco não guarda o token em claro';
  $t->post_ok($base, $H->($admin), json => { nome => 'Outra', email => $GEST })->status_is(409);
  $t->post_ok('/api/gestor/login', json => { email => $REDE, senha => 'qualquer1' })->status_is(401);
};

subtest 'convite: válido, substituído, usado, vencido' => sub {
  $t->get_ok("/api/rede/convite/$convite1")->status_is(200)
    ->json_is('/situacao' => 'valido')->json_is('/email' => $REDE);
  my $convite2 = $t->post_ok("$base/$conta/convite", $H->($admin))->status_is(201)->tx->res->json->{token};
  $t->get_ok("/api/rede/convite/$convite1")->json_is('/situacao' => 'substituido');
  $t->post_ok("/api/rede/convite/$convite1", json => { senha => 'segredo123' })->status_is(400);
  $t->post_ok("/api/rede/convite/$convite2", json => { senha => '123' })->status_is(400);
  $t->post_ok("/api/rede/convite/$convite2", json => { senha => 'segredo123' })->status_is(200)->json_is('/ok' => 1);
  $t->post_ok("/api/rede/convite/$convite2", json => { senha => 'outra1234' })->status_is(400);
  $t->get_ok("/api/rede/convite/$convite2")->json_is('/situacao' => 'usado');
  $t->get_ok('/api/rede/convite/' . ('x' x 43))->status_is(404);

  my $convite3 = $t->post_ok("$base/$conta/convite", $H->($admin))->status_is(201)->tx->res->json->{token};
  $dbh->do(q{UPDATE clean.rede_convites SET expira_em = NOW() - interval '1 minute'
              WHERE gestor_id = ? AND usado_em IS NULL AND invalidado_em IS NULL}, {}, $conta);
  $t->get_ok("/api/rede/convite/$convite3")->json_is('/situacao' => 'vencido');
  $t->post_ok("/api/rede/convite/$convite3", json => { senha => 'outra1234' })->status_is(400);

  $rede = $tok->($REDE, 'segredo123');
  ok $rede, 'login da conta de rede com a senha do convite';
  $t->post_ok('/api/gestor/login', json => { email => $REDE, senha => 'segredo123' })
    ->json_is('/gestor/access_role' => 'rede');
};

subtest 'sem vínculo: não vê escola nenhuma' => sub {
  $t->get_ok('/api/rede/me', $H->($rede))->status_is(200)->json_is('/vinculos' => [])
    ->json_is('/senha_definida' => Mojo::JSON::true);
  $t->get_ok('/api/rede/escolas', $H->($rede))->status_is(200)->json_is('/escolas' => []);
  $t->get_ok("/api/rede/escolas/$E{A}", $H->($rede))->status_is(403);
};

my $vinc_mun;
subtest 'vínculo municipal: só as escolas certas' => sub {
  $t->post_ok("$base/$conta/vinculos", $H->($admin), json => { tp_dependencia => 4, co_municipio => $M1 })->status_is(400);
  $t->post_ok("$base/$conta/vinculos", $H->($admin), json => { tp_dependencia => 3, co_municipio => 9990099 })->status_is(400)
    ->json_like('/error' => qr/Município não encontrado/);
  $vinc_mun = $t->post_ok("$base/$conta/vinculos", $H->($admin), json => { tp_dependencia => 3, co_municipio => $M1 })
    ->status_is(201)->json_is('/dependencia' => 'Municipal')->json_is('/municipio' => 'Vila Um')->tx->res->json->{id};
  $t->post_ok("$base/$conta/vinculos", $H->($admin), json => { tp_dependencia => 3, co_municipio => $M1 })->status_is(409);

  my $lista = $t->get_ok('/api/rede/escolas', $H->($rede))->status_is(200)->tx->res->json->{escolas};
  is [ map { $_->{cod_inep} } @$lista ], [ $E{A} ], 'só a A: B estadual, C outro município, D estadualizada, E paralisada, F privada';
  $t->get_ok("/api/rede/escolas/$E{A}", $H->($rede))->status_is(200)->json_is('/nome' => 'Escola A municipal');
  $t->get_ok("/api/rede/escolas/$_", $H->($rede))->status_is(403) for @E{qw(B C D F)};
};

subtest 'vínculo estadual soma a rede estadual do município' => sub {
  $t->post_ok("$base/$conta/vinculos", $H->($admin), json => { tp_dependencia => 2, co_municipio => $M1 })->status_is(201);
  my $lista = $t->get_ok('/api/rede/escolas', $H->($rede))->tx->res->json->{escolas};
  is [ sort map { $_->{cod_inep} } @$lista ], [ sort @E{qw(A B D)} ], 'A + B + D (situação atual estadual)';
  is scalar @{ $t->get_ok('/api/rede/me', $H->($rede))->tx->res->json->{vinculos} }, 2, 'dois vínculos';
};

subtest 'papéis separados' => sub {
  $t->get_ok("/api/gestor/$E{A}/planos", $H->($rede))->status_is(403)->json_like('/error' => qr/painel da rede/);
  $t->post_ok('/api/gestor/pesquisas', $H->($rede), json => { titulo => 'x' })->status_is(403);
  $t->get_ok('/api/gestor/me', $H->($rede))->status_is(200)->json_is('/access_role' => 'rede');
  $t->get_ok('/api/rede/me', $H->($gestor))->status_is(403);
  $t->get_ok('/api/rede/me', $H->($admin))->status_is(403);
  $t->get_ok('/api/rede/me')->status_is(401);
  $t->get_ok($base, $H->($rede))->status_is(403);
};

subtest 'revogar corta o acesso na hora' => sub {
  $t->delete_ok("$base/$conta/vinculos/$vinc_mun", $H->($admin))->status_is(200);
  $t->get_ok("/api/rede/escolas/$E{A}", $H->($rede))->status_is(403);
  $t->delete_ok("$base/$conta/vinculos/$vinc_mun", $H->($admin))->status_is(404);
  $t->get_ok("/api/rede/escolas/$E{B}", $H->($rede))->status_is(200, 'o vínculo estadual continua');
};

subtest 'listagem e auditoria' => sub {
  my $c = $t->get_ok($base, $H->($admin))->status_is(200)->tx->res->json->{contas};
  my ($minha) = grep { $_->{id} == $conta } @$c;
  is $minha->{senha_definida}, Mojo::JSON::true, 'senha definida';
  is [ map { $_->{dependencia} } @{ $minha->{vinculos} } ], [ 'Estadual' ], 'só o vínculo ativo';
  my $a = $t->get_ok("$base/$conta/auditoria", $H->($admin))->status_is(200)->tx->res->json->{auditoria};
  my %n; $n{ $_->{acao} }++ for @$a;
  is \%n, { conta_criada => 1, convite_gerado => 3, convite_aceito => 1, vinculo_concedido => 2, vinculo_revogado => 1 },
    'auditoria de tudo';
};

done_testing;
