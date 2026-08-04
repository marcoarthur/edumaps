# t/04-api/school/search_paginated.t
use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $path = "/api/school/search/pageable";
my $tag = "[school API] paginated search";

subtest qq/
$tag <busca paginada de escolas>
  - validações de parâmetros
  - verificação da estrutura de resposta
  - testes de paginação
/ => sub {

  # ---- VALIDAÇÕES DE PARÂMETROS ----

  # page não numérico
  $t->get_ok("$path?page=abc")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # per_page não numérico
  $t->get_ok("$path?per_page=xyz")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # page < 1
  $t->get_ok("$path?page=0")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # per_page < 1
  $t->get_ok("$path?per_page=0")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # per_page > 500 (limite máximo)
  $t->get_ok("$path?per_page=501")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # escola com menos de 3 caracteres (validação existente)
  $t->get_ok("$path?escola=ab")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # municipio com menos de 3 caracteres
  $t->get_ok("$path?municipio=sp")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # ---- RESPOSTAS VÁLIDAS ----

  # 1. Busca sem parâmetros (deve retornar primeira página com per_page padrão)
  my $tx = $t->get_ok("$path?escola=Maria")
  ->status_is(200)
  ->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'HASH', 'Resposta é um objeto');
  ok(exists $json->{data}, 'Campo data existe');
  ok(exists $json->{meta}, 'Campo meta existe');
  ok(ref($json->{data}) eq 'ARRAY', 'data é um array');
  ok(ref($json->{meta}) eq 'HASH', 'meta é um objeto');

  my $meta = $json->{meta};
  ok(exists $meta->{current_page}, 'meta.current_page existe');
  ok(exists $meta->{per_page},     'meta.per_page existe');
  ok(exists $meta->{total_entries}, 'meta.total_entries existe');
  ok(exists $meta->{total_pages},    'meta.total_pages existe');
  is($meta->{current_page}, 1, 'Página inicial é 1');
  is($meta->{per_page}, 10, 'per_page padrão é 10');

  # 2. Busca com paginação específica
  $tx = $t->get_ok("$path?escola=Maria&page=2&per_page=5")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  $meta = $json->{meta};
  is($meta->{current_page}, 2, 'Página correta');
  is($meta->{per_page}, 5, 'per_page respeitado');
  cmp_ok(scalar @{$json->{data}}, '<=', 5, 'Número de itens <= per_page');

  # 3. Busca com filtro e paginação (escola)
  $tx = $t->get_ok("$path?escola=Maria&page=1&per_page=3")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(@{$json->{data}} > 0, 'Retornou resultados para escola=Maria');
  $meta = $json->{meta};
  is($meta->{current_page}, 1, 'Página 1');
  is($meta->{per_page}, 3, 'per_page 3');

  # 4. Busca com filtro e paginação (municipio)
  $tx = $t->get_ok("$path?municipio=Ubatuba&page=2&per_page=2")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(@{$json->{data}} > 0, 'Retornou resultados para municipio=Ubatuba');
  $meta = $json->{meta};
  is($meta->{current_page}, 2, 'Página 2');
  is($meta->{per_page}, 2, 'per_page 2');

  # 5. Página além do limite (deve retornar 404 ou 400, conforme implementação)
  # Vamos assumir que get_page morre com "Exceed total page" -> 400
  $t->get_ok("$path?page=9999")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # 6. Busca sem resultados (deve retornar data vazio e meta com total_entries 0)
  $tx = $t->get_ok("$path?escola=ZZZXXYY")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  is(scalar @{$json->{data}}, 0, 'data vazio');
  is($json->{meta}->{total_entries}, 0, 'total_entries 0');
  is($json->{meta}->{total_pages}, 1, 'total_pages 1');
};

subtest qq/
  $tag: <API performance paginada>
  - validação para performance local
  - garante que o ciclo completo HTTP + JSON overhead da rota é aceitável
/ => sub {
  my $term = 'Maria';
  my $t0 = [gettimeofday];

  $t->get_ok("$path?escola=$term&page=1&per_page=20")
  ->status_is(200);

  my $elapsed = tv_interval($t0);
  my $max_api_time = 0.50; # um pouco mais tolerante pela paginação

  ok(
    $elapsed <= $max_api_time,
    sprintf("Tempo total da rota HTTP (%.4fs) dentro do limite esperado (%.2fs)", $elapsed, $max_api_time)
  );

  note sprintf("API Performance Info -> Rota: %s | Tempo de resposta: %.4f segundos", 
    $path, 
    $elapsed
  );
};

done_testing;
