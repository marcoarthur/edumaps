package EduMaps::Model::School;

use Mojo::Base "EduMaps::Model::Base", -signatures;
use DateTime;
use Mojo::Exception qw(raise);
use Role::Tiny::With;
use utf8;

has default_limit => 100;

our @BUSINESS_ROLES = map {
  "EduMaps::Roles::Business::School::$_"
} qw/Profile Geo Finance Scores Clustering Searching/;

with @BUSINESS_ROLES;

sub default_columns($self) {
  state $DEFAULT_COLS = [
    qw(escola codigo_inep latitude longitude endereco telefone municipio uf porte_escola),
    { osm => \q<'https://www.openstreetmap.org/?mlat=' || latitude || '&mlon=' || longitude ||'&zoom=18#map=18/' || latitude || '/' || longitude> },
    { whatsapp => \q<'https://wa.me/' || 55 || regexp_replace(telefone, '\D', '', 'g')> },
    { modalidades => \q<regexp_split_to_array(etapas_modalidades, '\s*,\s*')> },
    { tipo => 'dependencia_administrativa' },
  ];
};

sub _sanitize_like_pattern ($self, $string, $escape_char = '\\') {
    $$string =~ s/([%_\\])/$escape_char$1/g;
}

###########################################################################################
# PUBLIC METHODS
###########################################################################################

sub full_inep_grades($self, $params = {}) {
  my $inep = $self->schema->resultset('IdebNotasEscolas');

  return $inep->full_grade($params->{cod_inep});
}

sub ideb_grades($self, $params = {}) {
  my $rs = $self->schema->resultset('IdebNotasEscolas');

  $self->set_params_map(
    params => $params,
    map => {
      id_escola => [qw/cod_inep inep/],
    }
  );

  $self->json->encode($rs->all_grades_for( $params ) // {});
}

sub workers($self, $params = {}) {
  my $payroll = $self->schema->resultset('RemuneracaoMunicipal');

  $self->set_params_map(
    params => $params,
    map => {
      cod_inep  => [qw/cod_inep inep/],
      ano       => [qw/year ano/],
      categoria => [qw/category categoria/],
    }
  );

  my $columns = [qw(nome_profissional cpf segmento_ensino situacao carga_horaria ano categoria)];
  my $results = $payroll->search_rs($params)
  ->columns($columns)->distinct->as_hash->get_all;

  unless ($results->size) {
    return $self->json->encode({error => "Profissionais não encontrados", parametros => $params});
  }

  return $self->json->encode($results->to_array);
}

sub search_all_from($self, $params = {}) {
  my $school = $self->schema->resultset('Escolas');

  $self->set_params_map(
    params => $params,
    map => {
      municipio => [
        [qw(cidade)],
        sub ($cidade) { $self->_sanitize_like_pattern(\$cidade); +{-ilike => "$cidade"} }
      ],
    }
  );

  my $results = $school->search_rs($params)->columns($self->default_columns)->as_hash->get_all;
  return $self->json->encode($results->to_array);
}

sub gis_cover($self, $params = {}) {
  my $rs = $self->schema->resultset('Escolas');

  $self->set_params_map(
    params => $params,
    map => {
      codigo_inep => [qw(inep codigo_inep)],
      radius => [qw(radius raio)],
    }
  );

  my $properties = [qw/escola codigo_inep dependencia_administrativa raio_km/]; # properties
  my $radius = $params->{radius} || 5; # cover radius
  my $cover = qq<ST_Transform(
    ST_SetSRID(ST_Buffer(geography(geometry), $radius*1000)::geometry, 4674 ), 4326
  )>; # cover area

  return $self->json->encode( 
    {error => "raio ($radius) demasiado grande, máximo 10 km"}
  ) if $radius > 10;

  my $results = $rs->search_rs( { codigo_inep => $params->{codigo_inep} } )
  ->add_derived(cobertura => $cover, raio_km => $radius )
  ->as_subselect_rs->geojson_features('cobertura', $properties)
  ->as_hash->first;

  return $results->{feature};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

EduMaps::Model::School - Modelo para Escolas no EduMaps

=head1 DESCRIPTION

O Modelo representa os dados relacionados a unidade escolar. Desempenho em exames, dados
da escola segundo Censo Escolar, docentes, dados financeiros, de gestão, por fim, análises
e estatísticas para cada unidade.

=head1 AUTHOR

EduMaps Development Team

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2025 EduMaps. All rights reserved.

This software is part of the EduMaps educational mapping platform.

=cut
