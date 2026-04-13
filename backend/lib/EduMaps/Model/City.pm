package EduMaps::Model::City;

use Mojo::Base "EduMaps::Model::Base", -signatures;
use EduMaps::Model::School;
use JSON::PP qw();

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

  chop($code);

  my %workers = $self->schema->resultset('RemuneracaoMunicipal')
  ->search_rs( {cod_municipio => $code } )
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

=head2 payroll($ibge_code, $date)

Get payroll for the city in month and year.

=cut

sub payroll($self, $ibge_code, $date){
  my ($school, $city) = map { $self->schema->resultset($_) } qw(Escolas MunicipiosSp);

  my $params = { 
    ano => $date->year,mes => ucfirst($date->month_name) 
  },
  my $payroll = $school->search_rs(
    { 
      municipio => { 
        '=' => $city->search_rs( { codigo_ibge => $ibge_code } )->get_column('nome_municipio')->as_query 
      }
    }
  )->search_related_rs(
    'folha_pagamentos',
    { ano => $date->year, mes => ucfirst($date->month_name) },
    {
      columns => [
        { total_professores => { count => 'nome_profissional' } },
        { total_salarios => { sum => 'salario_total' } },
        qw(escola mes ano)
      ],
      group_by => [ qw(folha_pagamentos.escola mes ano) ]
    }
  )->as_hash->get_all;

  return $self->json->encode($payroll->to_array);
}

=head2 payroll_details($ibge_code,$date)

Get the list of all schools and they payroll related data for the month and year
specified by C<$date>.

=cut

=head3 Parameters

=over 4

=item * C<$ibge_code> (String) - String representing ibge_code of city

=item * C<$date> (DateTime) - DateTime object representing Year/Month of payroll

=back

=head3 Returns

=over 4

=item * String - JSON string with all payrolls found for each school of the city

=back

=head3 Notes

This method relates to C<EduMaps::Model::School::payroll> that list all workers and
their salaries for specific School.

=cut

sub payroll_details($self, $ibge_code, $date) {
  my $city_rs = $self->schema->resultset('MunicipiosSp');
  my $city_param = { codigo_ibge => $ibge_code };
  my $school_ids = $self->schema->resultset('Escolas')->search_rs(
    { municipio =>
      { '=' => $city_rs->search_rs($city_param)->get_column('nome_municipio')->as_query}
    },
    { columns => [qw(codigo_inep)] }
  )->as_hash->get_all;

  my $school = EduMaps::Model::School->new( schema => $self->schema );
  my $school_payroll = $school_ids->map(
    sub { $school->payroll($_->{codigo_inep}, $date)}
  );
  return sprintf('[%s]', $school_payroll->join(',')->to_string);
}

sub overall_payroll($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  $self->set_params_map(
    params => $params,
    map => {
      codigo_ibge => [qw/codigo_ibge/],
    },
  );
  return $self->json->encode([]) unless $params->{codigo_ibge};

  my $results = $rs->search_rs(
    {codigo_ibge => $params->{codigo_ibge}},
    {
      join => ['remuneracao_educacao'],
      columns => [
        qw(nome_municipio codigo_ibge nome_estado),
        { ano => 'remuneracao_educacao.ano' },
        { total_folha_salario => { sum => 'salario_total' }},
        { total_registros => { count => '*'} },
      ],
      distinct => 1,
    }
  )->as_hash->get_all;

  return $self->json->encode($results->to_array);
}

sub search_by_name($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  my $expr = \q{unaccent(nome_municipio) ILIKE unaccent(?)};
  my $results = $rs
  ->search_rs(\[$expr, $self->_wrap_percent($params->{name})])
  ->to_geojson->get_column('feature')->first;

  return $results;
}

sub city_details($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  # kind of fuzzy search
  my $expr = \q{unaccent(nome_municipio) ILIKE unaccent(?)};
  my $results = $rs
  ->search_rs(\[$expr, $self->_wrap_percent($params->{name})])
  ->columns([
      qw/
      nome_municipio nome_regiao_imediata nome_regiao area_km2 nome_estado
      codigo_ibge
      /
    ])
  ->as_hash->get_all;

  return $self->json->encode($results->to_array);
}

sub _wrap_percent($self, $value) { return "%$value%"; }

1;

__END__

=pod

=head1 NAME

EduMaps::Model::City - City data management for EduMaps application

=head1 SYNOPSIS

  use EduMaps::Model::City;
  
  my $city_model = EduMaps::Model::City->new(schema => $schema);
  
  # Get complete city information
  my $city_data = $city_model->details('3550308');
  
  # Get OSM landuse features
  my $geojson = $city_model->osm_features('3550308');

=head1 DESCRIPTION

This model provides comprehensive city data management for the EduMaps application. It aggregates information from multiple result sets including school distribution, education professionals statistics, school coverage analysis, and geographic features from OpenStreetMap.

The model is designed to be efficient with large datasets, using optimized database queries and avoiding unnecessary data transformations.

=head1 METHODS

=head2 details($code, $radius = 3000)

Returns complete city information including:

=over 4

=item * Basic city details from IBGE database

=item * School distribution categorized by size (small, medium, large)

=item * Education professionals count by type and teaching segment

=item * School coverage analysis within specified radius

=back

=head2 osm_features($code)

Returns OpenStreetMap landuse features as a GeoJSON FeatureCollection with metadata. The method uses string concatenation to avoid decoding/recoding the GeoJSON, making it memory-efficient for large datasets.

=head1 INTERNAL METHODS

=head2 _format_float_nums($hash)

Formats floating point numbers in a hash reference to two decimal places. This ensures consistent numeric formatting across API responses.

=head1 DEPENDENCIES

=over 4

=item * L<EduMaps::Model::Base> - Base model class

=item * L<Scalar::Util> - For numeric validation

=item * L<JSON::PP> - For JSON encoding with canonical sorting

=back

=head1 RELATED MODULES

=over 4

=item * L<EduMaps::Schema::Result::MunicipiosSp> - City data result set

=item * L<EduMaps::Schema::Result::Escolas> - Schools result set

=item * L<EduMaps::Schema::Result::AnaliseCoberturaEscolar> - School coverage analysis

=item * L<EduMaps::Schema::Result::RemuneracaoMunicipal> - Education professionals data

=item * L<EduMaps::Schema::Result::OsmLanduse> - OpenStreetMap landuse features

=back

=head1 AUTHOR

EduMaps Development Team

=head1 COPYRIGHT

Copyright (c) 2024 EduMaps. All rights reserved.

=cut
