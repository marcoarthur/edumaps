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
# Id da conversa criada no primeiro POST. O detalhe usa o id direto em vez de
# "a conversa mais recente da lista": qualquer outro POST no meio do arquivo
# mudaria a conversa devolvida e o teste passaria a medir a coisa errada.
my $CONV_ID;

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
  $CONV_ID = $json->{id};
};

subtest 'POST /api/chat/conversas — falha sem mensagens (400)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => { titulo => 'Vazia', messages => [] }
  )->status_is(400);
};

subtest 'POST /api/chat/conversas — meta invalido (400, nao 500)' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  # `meta` fora de um objeto não tem tradução para jsonb. Sem validação o
  # Postgres recusava e a resposta era 500 com a página de erro em HTML.
  for my $invalido (['texto solto', 'nao e json'], ['array', [1, 2, 3]], ['numero', 42]) {
    my ($nome, $meta) = @$invalido;
    my $r = $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
      json => { titulo => "Meta $nome", messages => [
        { role => 'user', content => 'x', meta => $meta },
      ]}
    );
    is $r->tx->res->code, 400, "meta como $nome devolve 400";
  }

  # e o caminho feliz continua: objeto vazio é válido
  $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => { titulo => 'Meta vazio ok', messages => [
      { role => 'user', content => 'x', meta => {} },
    ]}
  )->status_is(201);
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

  my $id = $CONV_ID;

  my $ok = $t->get_ok("/api/chat/conversas/$id", { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  my $json = $ok->tx->res->json;
  is $json->{id}, $id, 'id confere';
  ok $json->{messages}, 'tem mensagens';
  is scalar(@{$json->{messages}}), 2, '2 mensagens salvas';

  # `meta` é jsonb: precisa voltar como objeto. O ChatMessage.svelte lê
  # meta.timestamp / meta.sql / meta.origem, então uma string aqui some com a
  # metainformação da conversa salva sem erro nenhum na tela.
  my @metas = map { $_->{meta} } @{$json->{messages}};
  is scalar(grep { ref $_ ne 'HASH' } @metas), 0,
    'meta de toda mensagem volta como objeto, não como string JSON';
  my %ts = map { $_->{timestamp} => 1 } grep { ref $_ eq 'HASH' } @metas;
  ok $ts{'2025-09-25T10:00:00Z'}, 'meta preserva o timestamp enviado';
  ok $ts{'2025-09-25T10:00:05Z'}, 'meta preserva o timestamp da resposta';
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

  # Cria a própria conversa em vez de pegar a primeira da lista: o export
  # só numera "Resposta N" para mensagens de role `assistant`, e a conversa
  # mais recente do banco pode ter só `user`. Este teste só passava antes
  # porque `?ids[]=` era ignorado e o corpo vinha com *todas* as conversas
  # — ou seja, ele afirmava o que não testava.
  my $criada = $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
    json => { titulo => 'EXPORT-MD', messages => [
      { role => 'user',      content => 'pergunta do teste', meta => {} },
      { role => 'assistant', content => 'resposta do teste', meta => {} },
    ]}
  )->status_is(201)->tx->res->json;

  my $id = $criada->{id};
  ok $id, "conversa criada (id=$id)";

  my $ok = $t->get_ok("/api/chat/conversas/export?ids=$id", { Authorization => "Bearer $admin_token" })
    ->status_is(200);

  is $ok->tx->res->headers->content_type, 'text/markdown; charset=utf-8', 'content-type markdown';
  like $ok->tx->res->headers->content_disposition, qr/attachment.*\.md/, 'content-disposition .md';
  like $ok->tx->res->body, qr/^# Conversa: EXPORT-MD/, 'markdown começa com título';
  like $ok->tx->res->body, qr/## Pergunta 1/, 'contém Pergunta 1';
  like $ok->tx->res->body, qr/## Resposta 1/, 'contém Resposta 1';
  like $ok->tx->res->body, qr/pergunta do teste/, 'contém o conteúdo da pergunta';
  like $ok->tx->res->body, qr/resposta do teste/, 'contém o conteúdo da resposta';

  $t->delete_ok("/api/chat/conversas/$id", { Authorization => "Bearer $admin_token" })->status_is(204);
};

subtest 'GET /api/chat/conversas/export — o filtro por ids funciona' => sub {
  plan skip_all => 'migrations nao aplicadas' unless $has_tables;

  # Este teste usava `?ids[]=`, que o `to_hash` do Mojolicious NÃO converte:
  # a chave chegava literally `ids[]`, `to_hash->{ids}` era `undef` e o
  # filtro era ignorado — o export trazia TODAS as conversas do gestor e o
  # teste passava sem perceber. Além disso, com o filtro realmente aplicado
  # o `id` ficava ambíguo pelo JOIN com `mensagens` (500).
  my $criar = sub {
    my ($titulo) = @_;
    $t->post_ok('/api/chat/conversas', { Authorization => "Bearer $admin_token" },
      json => { titulo => $titulo, messages => [
        { role => 'user',   content => "pergunta de $titulo", meta => {} },
        { role => 'assistant', content => "resposta de $titulo", meta => {} },
      ]}
    )->status_is(201)->tx->res->json;
  };

  my $a = $criar->('EXPORT-FILTRO-A');
  my $b = $criar->('EXPORT-FILTRO-B');

  my $so_a = $t->get_ok("/api/chat/conversas/export?ids=$a->{id}",
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->body;

  # exatamente uma conversa no markdown
  my @titulos = $so_a =~ /^# Conversa: (.+)$/mg;
  is scalar @titulos, 1, 'exportou exatamente 1 conversa (o filtro valeu)';
  like $so_a, qr/EXPORT-FILTRO-A/, 'é a conversa pedida';
  unlike $so_a, qr/EXPORT-FILTRO-B/, 'NÃO vazou a outra conversa';

  # `ids[]` deve continuar aceito (tolerância), mas também filtrando
  my $so_a_bracket = $t->get_ok("/api/chat/conversas/export?ids[]=$a->{id}",
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->body;
  my @titulos_bracket = $so_a_bracket =~ /^# Conversa: (.+)$/mg;
  is scalar @titulos_bracket, 1, 'a forma ids[] também filtra (não vira "todas")';

  # duas ids de uma vez
  my $duas = $t->get_ok("/api/chat/conversas/export?ids=$a->{id}&ids=$b->{id}",
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->body;
  my @duas_titulos = $duas =~ /^# Conversa: (.+)$/mg;
  is scalar @duas_titulos, 2, 'ids repetidas devolvem as 2 conversas';

  # `all=1` traz ambas
  my $todas = $t->get_ok('/api/chat/conversas/export?all=1',
    { Authorization => "Bearer $admin_token" })->status_is(200)->tx->res->body;
  like $todas, qr/EXPORT-FILTRO-A/, 'all=1 inclui A';
  like $todas, qr/EXPORT-FILTRO-B/, 'all=1 inclui B';

  # limpeza
  $t->delete_ok("/api/chat/conversas/$a->{id}", { Authorization => "Bearer $admin_token" })->status_is(204);
  $t->delete_ok("/api/chat/conversas/$b->{id}", { Authorization => "Bearer $admin_token" })->status_is(204);
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