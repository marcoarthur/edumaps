package EduMaps::Roles::Business::City::Profile;
use Mojo::Base -role, -signatures;

requires qw(schema);

=head2 details($code, $radius = 3000)

Get complete city details including school coverage, education professionals statistics, and school categorization by size.

=cut

=head3 Parameters

=over 4

=item * C<$code> (String) - IBGE city code (7 digits)

=item * C<$radius> (Integer) - Search radius in meters for school coverage analysis

Default: 3000

=back

=head3 Returns

=over 4

=item * (HashRef) - Complete city information structure with:

  - detalhes_cidade: City basic information (name, region, coordinates)
  - porte_escola: School distribution by size category with counts and school IDs
  - profissionais_educacao: Education professionals count by type and teaching segment
  - cobertura_escolar: School coverage analysis within specified radius

=back

=head3 Example

  my $city_data = $city_model->details('3550308', 5000);
  
  say "City: " . $city_data->{detalhes_cidade}{nome_municipio};
  say "Large schools: " . $city_data->{porte_escola}{Grande}{total};
  say "Teachers: " . $city_data->{profissionais_educacao}{"Professor/Ensino Fundamental"};

=cut

sub details($self, $code, $radius = 3000) {
  my $city_details = $self->schema->resultset('MunicipiosSp')->details($code)->first;
  return {} unless keys %$city_details;

  my $school_cover = $self->schema->resultset('AnaliseCoberturaEscolar')
  ->search_rs(
    { codigo_ibge => $code },
    { bind => [ $radius ] },
  )->sumario_municipio->as_hash->first || {};

  my %categorias = $self->schema
  ->resultset('Escolas')->count_by_size($city_details->{nome_municipio})
  ->as_hash->get_all->map(
    sub {
      $_->{porte_escola} => { 
        total => $_->{total_por_porte},
        escolas => [split /,/, $_->{ids_escola}]
      }
    }
  )->@*;

  my $code_antigo = substr($code, 0, 6);

  my %workers = $self->schema->resultset('RemuneracaoMunicipal')
  ->search_rs( {cod_municipio => $code_antigo } )
  ->columns([qw/nome_profissional cpf tipo segmento_ensino/])
  ->distinct
  ->as_subselect_rs
  ->count_of([qw(tipo segmento_ensino)], 'total')
  ->as_hash
  ->get_all->map(
    sub { join("/", $_->{tipo}, $_->{segmento_ensino}) => $_->{total} }
  )->@*;

  $self->_format_float_nums($_) for $city_details, \%categorias, \%workers, $school_cover;
  return {
    detalhes_cidade => $city_details,
    porte_escola => \%categorias,
    profissionais_educacao => \%workers, 
    cobertura_escolar => $school_cover,
  };
}

=head2 osm_features($code)

Get OpenStreetMap landuse features for a city as GeoJSON with metadata.

=cut

=head3 Parameters

=over 4

=item * C<$code> (String) - IBGE city code (7 digits)

=back

=head3 Returns

=over 4

=item * (String) - JSON string with structure:

  {
    "meta": {
      "city_code": <code>,
      "generated_at": <timestamp>,
      "type": "landuse"
    },
    "geojson": <GeoJSON FeatureCollection>
  }

=back

=head3 Example

  my $geojson_data = $city_model->osm_features('3550308');
  
  # Use with Mojolicious render
  $c->render(json => $geojson_data);
  
  # Or decode for manipulation
  my $data = $c->json->decode($geojson_data);
  say "GeoJSON type: " . $data->{geojson}{type};

=head3 Notes

This method returns a JSON string without decoding/recoding the GeoJSON to avoid memory overhead with large datasets. The GeoJSON is concatenated directly with metadata for optimal performance.

=cut

sub osm_features($self, $code) {
  my $geojson = $self->schema->resultset('OsmLanduse')
  ->search_rs({municipio_id => $code})
  ->geojson_features('geom', [qw(properties municipio_id)])->get_column('feature')->first;
  my $metadata = $self->json->encode(
    {
      city_code     => $code,
      generated_at  => time,
      type          => 'landuse',
    }
  );

  return sprintf q/{"meta": %s, "geojson": %s}/, $metadata, $geojson;
}

1;
