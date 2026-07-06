# t/04-api/school/clustering.t
use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Utils qw(random_city_id);
use Test::Mojo;
use open ':std', ':encoding(UTF-8)';

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $path = "/api/school/cluster";
my $tag = "[school API] clustering:";

subtest qq/
$tag: <rota web para clustering e validacao de parametros de request>
  - parâmetro faltante
  - parâmetro inválido
  - parâmetro válido, mas sem resultado
  - parâmetro válido e com resultado
/ => sub {
  # missing parameter
  $t->get_ok("$path")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # invalid parameter
  $t->get_ok("$path?codigo_ibge=non_existent")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # valid but not found
  $t->get_ok("$path?codigo_ibge=9999999")
  ->status_is(404)
  ->json_like('/error' => qr/Não encontrado/);

  # valid and ok
  $t->get_ok("$path?codigo_ibge=2104073")
  ->status_is(200);
};


subtest qq/
$tag: <rota web para clustering verificação de contrato da API>
  - API obedece contrato esperado
  - Estrutura de retorno com contrato obedecido
  - Identicadores do clusters (inteiros 1-6)
  - Latitude e longitude válidos
/ => sub {
  my $c = random_city_id->first;
  my $code = $c->codigo_ibge;
  note( "Testando com cidade: " . $c->nome_municipio );
  my $tx = $t->get_ok("$path?codigo_ibge=$code")
  ->status_is(200)
  ->tx;

  my $json = $tx->res->json;
  map { 
    my $cluster_id = $_->{cluster_id};
    ok ($cluster_id >= 1 && $cluster_id <= 6, "($cluster_id) Identificador do cluster ids entre 1-6");
    map { 
      my ($lat, $lon) = ($_->{latitude}, $_->{longitude});
      ok ( $lat >= -90 && $lat <= 90, "latitude ($lat) escola correta" );
      ok ( $lon >= -180 && $lon <= 180, "longitude ($lon) escola correta" );
    } $_->{escolas}->@*;
  }
  @$json;

  like(
    $json,
    array {
      item '0' => hash {
        field cluster_id => qr/[0-9]/;
        field escolas => array {
          item '0' => hash {
            field aprovacao => number_ge(0) && number_le(100);
            field cluster_id => qr/[0-9]/;
            field escola => L();
            field latitude => L();
            field longitude => L();
            field municipio => L();
            field rede => L();
            field tendencia => L();
          };
          etc();
        };
        field media_aprovacao_percent => number_ge(0) && number_le(100);
        field media_ideb => number_ge(0) && number_le(10);
        field media_notas => number_ge(0) && number_le(10);
      };
    },
    'Contrato obedecido'
  ) or note diag $json;
};


subtest qq/
$tag: <API performance>
  - validação para performance local
  - garante que o ciclo completo HTTP + JSON overhead da rota é aceitável
/ => sub {
  # Usando o mesmo código IBGE válido dos testes anteriores (Davinópolis - MA)
  my $ibge = '2104073'; 

  # 1. Inicia o cronômetro antes do disparo da requisição
  my $t0 = [gettimeofday];

  $t->get_ok("$path?codigo_ibge=$ibge")
  ->status_is(200);

  # 2. Finaliza a contagem
  my $elapsed = tv_interval($t0);

  # Para o ciclo HTTP local completo (incluindo renderização de JSON massivo),
  # um teto de 600ms (0.60s) é uma métrica excelente e saudável.
  my $max_api_time = 0.40;

  ok(
    $elapsed <=
    $max_api_time, 
    sprintf("Tempo total da rota HTTP (%.4fs) dentro do limite esperado (%.2fs)", $elapsed, $max_api_time)
  );

  # Diagnóstico limpo no terminal durante os testes
  note sprintf("API Performance Info -> Rota: %s | Tempo de resposta: %.4f segundos", 
    $path, 
    $elapsed
  );
};

done_testing;
