# t/04-api/gestor/agenda_responsavel.t
# Testes do gestor responsável pela agenda (Plano A):
#   perfil_escola (gestores + responsável pela agenda),
#   auto-cadastro governado (409 quando novo e-mail p/ escola com agenda) e
#   transferência do vínculo da agenda. Exige sessão do gestor da escola.
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $has_tables = $t->app->schema->storage->dbh->selectrow_array(
  "SELECT to_regclass('clean.reunioes')"
);

my $INEP  = '77777777';
my $OUTRA = '66666666';
my $SENHA = 'senha123';

my $email_a = sprintf 'resp.a.%d@edumaps.test', $$;
my $email_b = sprintf 'resp.b.%d@edumaps.test', $$;
my $email_c = sprintf 'resp.c.%d@edumaps.test', $$;
my $email_novo = sprintf 'resp.novo.%d@edumaps.test', $$;
my $email_intrusa = sprintf 'intrusa.%d@edumaps.test', $$;

my ($token_a, $token_b, $token_c, $id_a, $id_b, $id_c);
my $auth = sub ($tok) { { Authorization => "Bearer $tok" } };
my $auth_a = sub { $auth->($token_a) };
my $auth_b = sub { $auth->($token_b) };

if ($has_tables) {
  my $dbh = $t->app->schema->storage->dbh;
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste do responsável da agenda');
  }
}

END {
  return if !$has_tables;
  my $dbh = $t->app->schema->storage->dbh;
  for my $email ($email_a, $email_b, $email_c, $email_novo, $email_intrusa) {
    $dbh->do('DELETE FROM clean.gestores WHERE email = ?', {}, $email);
  }
  for my $inep ($INEP, $OUTRA) {
    $dbh->do('DELETE FROM clean.contato_grupos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.contatos WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.reunioes WHERE cod_inep = ?', {}, $inep);
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'setup: dois gestores da escola + um de outra' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $pa = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Responsável A', email => $email_a, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $id_a = $pa->{id};

  my $pb = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Responsável B', email => $email_b, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $id_b = $pb->{id};

  my $pc = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $OUTRA, nome => 'Outra Escola C', email => $email_c, senha => $SENHA,
  })->status_is(200)->tx->res->json;
  $id_c = $pc->{id};

  $token_a = $t->post_ok('/api/gestor/login', json => { email => $email_a, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  $token_b = $t->post_ok('/api/gestor/login', json => { email => $email_b, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
  $token_c = $t->post_ok('/api/gestor/login', json => { email => $email_c, senha => $SENHA })
    ->status_is(200)->tx->res->json->{token};
};

subtest 'perfil_escola: lista os gestores e (ainda) sem responsável' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $perfil = $t->get_ok("/api/gestor/$INEP", $auth_a->())
    ->status_is(200)->tx->res->json;
  is scalar(@{$perfil->{gestores}}), 2, 'dois gestores da escola';
  is $perfil->{gestores}[0]{id}, $id_a, 'primeiro é o A';
  ok !defined $perfil->{responsavel}, 'sem reunião ainda: responsável nulo';
};

subtest 'auto-cadastro governado: 409 para novo e-mail em escola com agenda' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  # antes de existir agenda, um novo e-mail ainda se registra na escola
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Novo Sem Agenda', email => $email_novo, senha => $SENHA,
  })->status_is(200);

  # cria o contato + primeira reunião (agenda nasce)
  my $contato = $t->post_ok("/api/gestor/$INEP/contatos", $auth_a->(), json => {
    nome => 'Participante', email => 'participante.responsavel@edu.test',
  })->status_is(201)->tx->res->json;

  $t->post_ok("/api/gestor/$INEP/reunioes", $auth_a->(), json => {
    titulo      => 'Reunião do responsável',
    quando      => '2026-11-05T10:00:00',
    duracao_min => 60,
    contato_ids => [ $contato->{id} ],
  })->status_is(201);

  # novo e-mail: 409
  my $err = $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Intrusa', email => $email_intrusa, senha => $SENHA,
  })->status_is(409)->tx->res->json;
  like $err->{error}, qr/já tem um gestor responsável/, 'mensagem orienta transferência';

  # o mesmo e-mail (upsert/re-login) continua permitido
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP, nome => 'Responsável A', email => $email_a, senha => $SENHA,
  })->status_is(200);
};

subtest 'transferência: só o responsável transfere e só dentro da escola' => sub {
  plan skip_all => 'clean.reunioes ausente (migration nao aplicada)'
    unless $has_tables;

  my $perfil = $t->get_ok("/api/gestor/$INEP", $auth_a->())
    ->status_is(200)->tx->res->json;
  is $perfil->{responsavel}{id}, $id_a, 'A criou a 1ª reunião: é o responsável';

  # B ainda não pode transferir (não é o responsável)
  $t->post_ok("/api/gestor/$INEP/transferencia", $auth_b->(), json => { novo_gestor_id => $id_a })
    ->status_is(403);

  # destino fora da escola: 404
  $t->post_ok("/api/gestor/$INEP/transferencia", $auth_a->(), json => { novo_gestor_id => $id_c })
    ->status_is(404);

  # A (responsável) transfere para B
  my $tx = $t->post_ok("/api/gestor/$INEP/transferencia", $auth_a->(), json => { novo_gestor_id => $id_b })
    ->status_is(200)->tx->res->json;
  is $tx->{ok}, 1, 'transferência confirmada';
  is $tx->{gestor_id}, $id_b, 'novo vinculo é o gestor B';

  # perfil pós-transferência aponta B como responsável
  my $pos = $t->get_ok("/api/gestor/$INEP", $auth_a->())
    ->status_is(200)->tx->res->json;
  is $pos->{responsavel}{id}, $id_b, 'responsável agora é o B';

  # A deixou de ser responsável: transferir de novo dá 403
  $t->post_ok("/api/gestor/$INEP/transferencia", $auth_a->(), json => { novo_gestor_id => $id_b })
    ->status_is(403);

  # B (novo responsável) devolve para A — fecha o ciclo
  $t->post_ok("/api/gestor/$INEP/transferencia", $auth_b->(), json => { novo_gestor_id => $id_a })
    ->status_is(200);

  # gestor de outra escola simplesmente não acessa a rota da escola
  $t->get_ok("/api/gestor/$INEP", $auth->($token_c))->status_is(403);
};

done_testing;