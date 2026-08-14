use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');

# Garante a existência de um cache mock CHI para isolamento dos testes
unless ($t->app->can('chi') && $t->app->chi) {
  use CHI;
  my $cache = CHI->new(driver => 'Memory', global => 1);
  $t->app->helper(chi => sub { $cache });
}

# Registra o middleware explicitamente no app
$t->app->plugin('EduMaps::Middleware::Cache::SchoolSearch');

subtest 'Middleware Cache: MISS -> HIT e Preservação de UTF-8' => sub {
  my $endpoint = '/api/school/suggestions?q=santuario';

  $t->app->chi->clear;

  # 1ª Requisição -> Deve processar via controller e retornar MISS
  my $tx1 = $t->get_ok($endpoint)
  ->status_is(200)
  ->header_is('X-Cache' => 'MISS')
  ->tx;

  my $bytes_miss = $tx1->res->body;
  my $json_miss  = $tx1->res->json;

  # 2ª Requisição -> Deve ser servida direto pelo Cache e retornar HIT
  my $tx2 = $t->get_ok($endpoint)
  ->status_is(200)
  ->header_is('X-Cache' => 'HIT')
  ->tx;

  my $bytes_hit = $tx2->res->body;
  my $json_hit  = $tx2->res->json;

  # Validação de integridade do Payload (Sem Double UTF-8)
  is $bytes_hit, $bytes_miss, 'Tamanho em bytes do HIT é idêntico ao MISS';
  is $json_hit,  $json_miss,  'Estrutura do JSON retornado do HIT é exatamente igual ao MISS';

  if (my $item_com_acento = (grep { $_->{municipio} =~ /[áéíóúãõç]/i } $json_hit->@*)[0]) {
    like $item_com_acento->{municipio}, qr/[áéíóúãõç]/i, 'Acentuação UTF-8 preservada corretamente no HIT';
  }
};

subtest 'Middleware Cache: Diferenciação de Chaves por Query String' => sub {
  $t->app->chi->clear;

  $t->get_ok('/api/school/suggestions?q=santuario')
  ->status_is(200)
  ->header_is('X-Cache' => 'MISS');

  $t->get_ok('/api/school/suggestions?q=santuario')
  ->status_is(200)
  ->header_is('X-Cache' => 'HIT');

  # Query B (Diferente parâmetro -> gera nova chave e retorna MISS)
  $t->get_ok('/api/school/suggestions?q=pedro')
  ->status_is(200)
  ->header_is('X-Cache' => 'MISS');
};

subtest 'Middleware Cache: Não armazena em cache HTTP != 200 (Bad Request)' => sub {
  $t->app->chi->clear;

  # Rota auditada /api/analytics/city/similar_to chamada sem os parâmetros obrigatórios
  my $path_bad = '/api/analytics/city/similar_to';

  $t->get_ok($path_bad)
  ->status_is(400)
  ->header_is('X-Cache' => 'MISS');

  # Segunda requisição -> Continua retornando MISS pois o status 400 não foi salvo no CHI
  $t->get_ok($path_bad)
  ->status_is(400)
  ->header_is('X-Cache' => 'MISS');
};

subtest 'Middleware Cache: Não armazena resultados vazios "[]"' => sub {
  $t->app->chi->clear;

  my $path_empty = '/api/school/suggestions?q=termo_inexistente_xyz_123';

  $t->get_ok($path_empty)
  ->status_is(200)
  ->header_is('X-Cache' => 'MISS')
  ->json_is([]);

  # Segunda requisição -> Permanece MISS porque payloads "[]" não são mantidos em cache
  $t->get_ok($path_empty)
  ->status_is(200)
  ->header_is('X-Cache' => 'MISS');
};

subtest 'Middleware Cache: Pulo de rotas não elegíveis' => sub {
  $t->app->chi->clear;

  # Rota fora da lista de buscas auditadas
  my $path_uncovered = '/api/school/12345678/info';

  $t->get_ok($path_uncovered)
  ->header_exists_not('X-Cache');
};

done_testing;
