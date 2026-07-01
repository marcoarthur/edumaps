use strictures 2;
use lib qw(t/lib lib);
use Imports;
use Test::Mojo;
use ok 'EduMaps::Schema';
use ok 'EduMaps::Model::School';
use open ':std', ':encoding(UTF-8)';
use utf8;

my $schema = EduMaps::Schema->go;
my $model = EduMaps::Model::School->new(schema => $schema);
my $tag = '[school model] geo:';

subtest qq/
$tag busca por proximidade
 - Coordenadas válidas (-23.54271,-45.231964) -> resultados esperados
 - Coordenadas sem escolas (alto mar) -> sem resultados
/ => sub {
  # Coordenadas de um ponto em Ubatuba (mesmo do teste manual)
  my $lat = -23.54271;
  my $lon = -45.231964;

  my $params = {
    latitude  => $lat,
    longitude => $lon,
    distance  => 5,    # 5 km
    limit     => 10,
  };

  my $results = $model->search_nearby($params);
  isa_ok($results, 'Mojo::Collection');

  ok($results->size > 0, 'Encontrou escolas próximas') or diag "Nenhuma escola próxima; pule ou use dados de fixture";

  my $first = $results->first;
  is(
    $first,
    hash {
      field codigo_inep    => L();
      field escola         => L();
      field municipio      => L();
      field uf             => L();
      field endereco       => L();
      field telefone       => L();
      field whatsapp       => match(qr{^https://wa\.me/});
      field latitude       => number_gt(-90) && number_lt(90);
      field longitude      => number_gt(-180) && number_lt(180);
      field osm            => match(qr{^https://www\.openstreetmap\.org/});
      field tipo           => L();
      field porte_escola   => L();
      field modalidades    => array { item L(); etc(); };
      field distancia      => number_gt(0);
      etc();
    },
    'Estrutura do item de escola está correta'
  );

  $results->each( sub { ok $_->{distancia} <= 5000, 'resultado dentro do limite de 5km' });

  my $ordered = $results->sort(sub { $a->{distancia} <=> $b->{distancia} });
  is($ordered->to_array, $results->to_array, 'Resultados ordenados de modo crescente');

  my $params_close = { %$params, distance => 1 };
  my $results_close = $model->search_nearby($params_close);
  ok($results_close->size <= $results->size, 'Distância menor retorna menos ou igual resultados');

  my $params_far = {
    latitude  => -23.0,
    longitude => -40.0,
    distance  => 10,
    limit     => 10,
  };
  my $results_far = $model->search_nearby($params_far);
  is($results_far->size, 0, 'Sem escolas próximas retorna coleção vazia');

  my $params_limit = { %$params, limit => 3 };
  my $results_limit = $model->search_nearby($params_limit);
  ok($results_limit->size <= 3, 'Respeita o limite de 3 resultados');
};

done_testing;
