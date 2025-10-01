package MyApp::Schema::ResultSet::Escola;
use Mojo::Base 'MyApp::Schema::ResultSet::Base', -signatures;

sub with_geojson($self) {

  $self->search_rs(
    undef,
    {
      '+select' => [{ST_AsGeoJSON => 'geom', -as => 'coordenadas'}],
      '+as'     => [qw/coordenadas/],
    }
  );
}

sub find_by_city_name($self, $name) {
  $self->search_rs({municipio => $name})
  ->geojson_features(
    'geom',
    [ qw(endereco escola municipio categoria_administrativa telefone) ]
  );
}

1;
