use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use utf8;
use open ':std', ':encoding(UTF-8)';
use DDP;

my $t = Test::Mojo->new('EduMaps');
$t->app->log->level('fatal');
my $path = "/api/analytics/city/similar_to";
my $cod = 2302701;

subtest q{municipio: tratamento de entradas (parametros da requisicao) } => sub {
  # missing parameter
  $t->get_ok("$path")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # bad parameter
  $t->get_ok("$path?codigo_ibge=non_existent")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

  # bad similarity (between 0,1)
  $t->get_ok("$path?codigo_ibge=$cod&similarity=10")
  ->status_is(400)
  ->content_like(qr/Bad request/i);

};

subtest 'validação de parâmetros (Bad Request)' => sub {
    my $path = '/api/analytics/city/similar_to';

    # 1) missing codigo_ibge
    $t->get_ok($path)->status_is(400)->content_like(qr/Bad request/i);

    # 2) codigo_ibge não numérico
    $t->get_ok("$path?codigo_ibge=abc")->status_is(400)->content_like(qr/Bad request/i);

    # 3) codigo_ibge com menos dígitos
    $t->get_ok("$path?codigo_ibge=123")->status_is(400)->content_like(qr/Bad request/i);

    # 4) codigo_ibge com mais dígitos
    $t->get_ok("$path?codigo_ibge=12345678")->status_is(400)->content_like(qr/Bad request/i);

    # 5) limit não numérico
    $t->get_ok("$path?codigo_ibge=$cod&limit=abc")->status_is(400)->content_like(qr/Bad request/i);

    # 6) limit < 1
    $t->get_ok("$path?codigo_ibge=$cod&limit=0")->status_is(400)->content_like(qr/Bad request/i);

    # 7) limit > 100
    $t->get_ok("$path?codigo_ibge=$cod&limit=200")->status_is(400)->content_like(qr/Bad request/i);

    # 8) similarity não numérico
    $t->get_ok("$path?codigo_ibge=$cod&similarity=abc")->status_is(400)->content_like(qr/Bad request/i);

    # 9) similarity < 0
    $t->get_ok("$path?codigo_ibge=$cod&similarity=-1")->status_is(400)->content_like(qr/Bad request/i);

    # 10) similarity > 1 (já testado, mantido)
    $t->get_ok("$path?codigo_ibge=$cod&similarity=10")->status_is(400)->content_like(qr/Bad request/i);

    # 11) múltiplos erros
    $t->get_ok("$path?codigo_ibge=123&limit=0&similarity=abc")
        ->status_is(400)
        ->content_like(qr/Bad request/i);
};

subtest q{municipio: similaridade entre municipios medida simples} => sub {
  my $tx = $t->get_ok("$path?codigo_ibge=$cod")->tx;
  my $results = $tx->res->json;

  ok scalar($results->@*) <= 10, 'tamanho máximo por default';

  is(
    $_,
    hash {
      field codigo_ibge => L();
      field area_km2 => L();
      field nome_estado => L();
      field similaridade => L();
      field distancia_euclidiana => L();
      etc();
    },
    'estrutura de retorno esperada'
  ) for $results->@*;

  $tx = $t->get_ok("$path?codigo_ibge=$cod&limit=4&similarity=0.8")->tx;
  $results = $tx->res->json;
  ok scalar($results->@*) <= 4, 'tamanho máximo é 4 agora';
  is(
    $_,
    hash {
      field codigo_ibge => L();
      field area_km2 => L();
      field nome_estado => L();
      field similaridade => number_gt(0.8);
      field distancia_euclidiana => L();
      etc();
    },
    'estrutura de retorno esperada'
  ) for $results->@*;
};

done_testing;
