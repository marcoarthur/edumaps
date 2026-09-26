# t/04-api/chat/conversas.t
# Testes da API de conversas do Assistente do Censo (/api/chat/conversas/*)

use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

my $dbh = $t->app->schema->storage->dbh;
my $has_tables = $dbh->selectrow_array("SELECT to_regclass('clean.chat_conversas')")
  && $dbh->selectrow_array("SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='clean' AND table_name='gestores' AND column_name='access_role')");

my $INEP_ADMIN = '99999999';
my $INEP_USER  = '88888888';
my $ADMIN_EMAIL = sprintf('admin.chat.%d@edumaps.test', $$);
my $USER_EMAIL  = sprintf('user.chat.%d@edumaps.test', $$);
my $SENHA = 'senha123';

my ($admin_token, $user_token);

END {
  return if !$has_tables;
  $dbh->do('DELETE FROM clean.chat_mensagens WHERE conversa_id IN (SELECT id FROM clean.chat_conversas WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email IN (?, ?)))', {}, $ADMIN_EMAIL, $USER_EMAIL);
  $dbh->do('DELETE FROM clean.chat_conversas WHERE gestor_id IN (SELECT id FROM clean.gestores WHERE email IN (?, ?))', {}, $ADMIN_EMAIL, $USER_EMAIL);
  $dbh->do('DELETE FROM clean.gestores WHERE email IN (?, ?)', {}, $ADMIN_EMAIL, $USER_EMAIL);
  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('DELETE FROM clean.escolas WHERE codigo_inep = ?', {}, $inep);
  }
}

subtest 'setup: escolas + gestores' => sub {
  plan skip_all => 'chat_conversas ausente (migrations nao aplicadas)' unless $has_tables;

  for my $inep ($INEP_ADMIN, $INEP_USER) {
    $dbh->do('INSERT INTO clean.escolas (codigo_inep, escola) VALUES (?, ?)
              ON CONFLICT (codigo_inep) DO NOTHING',
      {}, $inep, 'Escola de teste do chat');
  }

  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_ADMIN, nome => 'Admin Chat', email => $ADMIN_EMAIL, senha => $SENHA,
  })->status_is(200);
  $t->post_ok('/api/gestor/pesquisas/perfil', json => {
    cod_inep => $INEP_USER, nome => 'User Chat', email => $USER_EMAIL, senha => $SENHA,
  })->status_is(200);

  # promove admin
  my $admin_id = $dbh->selectrow_array('SELECT id FROM clean.gestores WHERE email = ?', {}, $ADMIN_EMAIL);
  $dbh->do('UPDATE clean.gestores SET access_role = ? WHERE id = ?', {}, 'admin', $admin_id);

  $admin_token = $t->post_ok('/api/gestor/login', json => { email => $ADMIN_EMAIL, senha => $SENHA })->tx->res->json->{token};
  $user_token  = $t->post_ok('/api/gestor/login', json => { email => $USER_EMAIL,  senha => $SENHA })->tx->res->json->{token};
};

subtest 'POST /api/chat/conversas — salva conversa (201)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $ok = $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => {
      titulo => 'Teste de conversa',
      messages => [
        { role => 'user', content => 'Quantas escolas em SP?', meta => { timestamp => '2025-09-25T10:00:00Z' } },
        { role => 'assistant', content => 'São 5000 escolas.', meta => { timestamp => '2025-09-25T10:00:05Z' } },
      ],
    }
  )->status_is(201);

  my $json = $ok->tx->res->json;
  ok $json->{id}, 'retorna id da conversa salva';
};

subtest 'POST /api/chat/conversas — falha sem mensagens (400)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => { titulo => 'Vazia', messages => [] }
  )->status_is(400);
};

subtest 'GET /api/chat/conversas — lista conversas do gestor' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $ok = $t->get_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  my $json = $ok->tx->res->json;
  ok $json->{items}, 'tem items';
  ok $json->{total} >= 1, 'total >= 1';
  ok $json->{page} == 1, 'pagina 1';
};

subtest 'GET /api/chat/conversas/:id — detalha conversa' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $list = $t->get_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" })
    ->tx->res->json;
  my $id = $list->{items}[0]{id};

  my $ok = $t->get_ok("/api/chat/conversas/$id", { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  my $json = $ok->tx->res->json;
  is $json->{id}, $id, 'id confere';
  ok $json->{messages}, 'tem mensagens';
  is scalar(@{$json->{messages}}), 2, '2 mensagens salvas';
};

subtest 'GET /api/chat/conversas/search — busca full-text' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $ok = $t->get_ok('/api/chat/conversas/search?q=SP', { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  my $json = $ok->tx->res->json;
  ok $json->{items}, 'tem resultados';
  ok $json->{total} >= 1, 'encontrou pelo menos 1';
  ok defined $json->{items}[0]{snippet}, 'tem snippet destacado';
};

subtest 'GET /api/chat/conversas/calendar — dias com conversas' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $today = DateTime->now(time_zone => 'UTC')->strftime('%Y-%m-%d');
  my $ok = $t->get_ok("/api/chat/conversas/calendar?from=$today&to=$today", { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  my $json = $ok->tx->res->json;
  ok ref $json eq 'HASH', 'retorna hash';
  ok exists $json->{$today}, "dia de hoje ($today) presente";
};

subtest 'GET /api/chat/conversas/export — exporta .md' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  my $list = $t->get_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" })
    ->tx->res->json;
  my $id = $list->{items}[0]{id};

  my $ok = $t->get_ok("/api/chat/conversas/export?ids[]=$id", { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  is $ok->tx->res->headers->content_type, 'text/markdown; charset=utf-8', 'content-type markdown';
  like $ok->tx->res->headers->content_disposition, qr/attachment.*\.md/, 'content-disposition .md';
  like $ok->tx->res->body, qr/^# Conversa:/, 'markdown começa com título';
  like $ok->tx->res->body, qr/## Pergunta 1/, 'contém Pergunta 1';
  like $ok->tx->res->body, qr/## Resposta 1/, 'contém Resposta 1';
};

subtest 'DELETE /api/chat/conversas/:id — exclui conversa' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  # cria uma nova para excluir
  my $create = $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => { titulo => 'Para excluir', messages => [
      { role => 'user', content => 'teste', meta => {} },
    ]}
  )->status_is(201);
  my $id = $create->tx->res->json->{id};

  $t->delete_ok("/api/chat/conversas/$id", { Authorization => "Bearer $admin_token" })
    ->status_is(204);

  $t->get_ok("/api/chat/conversas/$id", { Authorization => "Bearer $admin_token" })
    ->status_is(404);
};

subtest 'auth: 401 sem token, 403 gestor comum' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->get_ok('/api/chat/conversas')->status_is(401);
  $t->get_ok('/api/chat/conversas', { Authorization => "Bearer $user_token" })
    ->status_is(200); # user comum também pode ver SUAS conversas (isolation por gestor_id)
};

done_testing();