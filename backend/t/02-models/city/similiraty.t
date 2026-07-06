use strictures 2;
use lib qw(./lib t/lib);
use Imports;
use EduMaps::Model::City;
use EduMaps::Schema;

my $schema = EduMaps::Schema->go;

my $city_model = EduMaps::Model::City->new(schema => $schema);
isa_ok($city_model, 'EduMaps::Model::City');
my $DFT_SIZE = 10;

subtest q/similar_cities() lista de similiraride para um municipio/ => sub {
  my $params = [ 
    { codigo_ibge => 3555406, limit => 5 },
    { codigo_ibge => 5107040, limit => 3, similarity => 0.7 }
  ];
  for my $p ($params->@*) {
    my $ret = $city_model->similar_cities($p);
    isa_ok($ret, 'Mojo::Collection');
    ok $ret->size <= $p->{limit} || $DFT_SIZE, 'Tamanho menor ou igual ao limite';

    $ret->each(
      sub {
        ok ref($_), 'HASH', 'é uma hash';
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
        );
      }
    );
  }
};

done_testing;
