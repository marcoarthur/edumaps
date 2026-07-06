#t/04-api/school/searching.t
use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';


my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $path = "/api/school/search";
my $tag = "[school API] searching";


subtest qq/
  $tag <busca de escolas via API>
  - validações parametros de requisicao
  - verificacões de respostas da API (válidas; inválidas)
/ => sub {

  # escola com menos de 3 caracteres
  $t->get_ok("$path?escola=ab")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # municipio com menos de 3 caracteres
  $t->get_ok("$path?municipio=sp")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # limit não numérico
  $t->get_ok("$path?limit=abc")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # limit < 1
  $t->get_ok("$path?limit=0")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # limit > 500
  $t->get_ok("$path?limit=501")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # ---- RESPOSTAS VÁLIDAS ----

  # 1. Busca por escola (deve retornar 200 e array)
  my $tx = $t->get_ok("$path?escola=Maria")
  ->status_is(200)
  ->tx;
  my $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  if (@$json) {
    ok(exists $json->[0]{codigo_inep}, 'Campo codigo_inep presente');
    ok(exists $json->[0]{escola}, 'Campo escola presente');
    ok(exists $json->[0]{municipio}, 'Campo municipio presente');
    ok(exists $json->[0]{uf}, 'Campo uf presente');
  }

  # 2. Busca por municipio
  $tx = $t->get_ok("$path?municipio=Ubatuba")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  if (@$json) {
    ok(exists $json->[0]{municipio}, 'Campo municipio presente');
    like($json->[0]{municipio}, qr/Ubatuba/i, 'Municipio corresponde');
  }

  # 3. Busca com limit (deve respeitar)
  $tx = $t->get_ok("$path?limit=3")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  cmp_ok(scalar @$json, '<=', 3, 'Limit respeitado (máximo 3)');

  # 4. Busca com combinação de parâmetros
  $tx = $t->get_ok("$path?escola=Maria&municipio=Ubatuba")
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');
  if (@$json) {
    ok(exists $json->[0]{escola}, 'Campo escola presente');
    ok(exists $json->[0]{municipio}, 'Campo municipio presente');
  }

  # 5. Busca sem parâmetros (default limit do modelo)
  $tx = $t->get_ok($path)
  ->status_is(200)
  ->tx;
  $json = $tx->res->json;
  ok(ref($json) eq 'ARRAY', 'Resposta é um array');

  # O default limit do modelo deve ser 10 (ou o valor definido)
  cmp_ok(scalar @$json, '<=', 100, 'Limit padrão (100) respeitado');
};

subtest qq/
$tag: <API performance>
  - validação para performance local
  - garante que o ciclo completo HTTP + JSON overhead da rota é aceitável
/ => sub {
  # Usando um termo de busca que deve retornar alguns resultados
  my $term = 'Maria';  # ou 'Ubatuba' para mais resultados

  # 1. Inicia o cronômetro antes do disparo da requisição
  my $t0 = [gettimeofday];

  $t->get_ok("$path?escola=$term")
  ->status_is(200);

  # 2. Finaliza a contagem
  my $elapsed = tv_interval($t0);

  # Para o ciclo HTTP local completo (incluindo renderização de JSON),
  # um teto de 400ms (0.40s) é uma métrica excelente e saudável.
  my $max_api_time = 0.40;

  ok(
    $elapsed <= $max_api_time,
    sprintf("Tempo total da rota HTTP (%.4fs) dentro do limite esperado (%.2fs)", $elapsed, $max_api_time)
  );

  # Diagnóstico limpo no terminal durante os testes
  note sprintf("API Performance Info -> Rota: %s | Tempo de resposta: %.4f segundos", 
    $path, 
    $elapsed
  );
};

done_testing;
