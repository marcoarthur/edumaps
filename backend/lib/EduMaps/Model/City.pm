package EduMaps::Model::City;
use Mojo::Base "EduMaps::Model::Base", -signatures;

use EduMaps::Model::School;
use Role::Tiny::With;
use Carp qw(croak);
use utf8;
our @BUSINESS_ROLES = map {
  "EduMaps::Roles::Business::City::$_"
} qw/Profile Finance Analytic Geo Searching/;

with @BUSINESS_ROLES;

sub search_by_name($self, $params = {}) {
  
  my $results = $self->_search_unaccent($params->{name})
  ->to_geojson->get_column('feature')->first;

  return $results // '{"type":"FeatureCollection","features":[]}';
}

sub city_details($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  my $expr = q{unaccent(nome_municipio) ILIKE unaccent(?)};
  my $results = $rs
  ->search_rs(\[$expr, $self->_wrap_percent($params->{name})])
  ->columns(
    [
      qw/
      nome_municipio nome_regiao_imediata nome_regiao area_km2 nome_estado
      codigo_ibge
      /
    ]
  )
  ->as_hash->get_all;

  return $self->json->encode($results->to_array);
}

sub search_for_complete($self, $params = {}) {
  my $rs = $self->schema->resultset('MunicipiosSp');

  $self->set_params_map(
    params => $params,
    map => {
      term => [qw/q query/],
      limit => [qw/limit/],
    },
  );

  my $cols = [
    qw(me.nome_municipio me.sigla_estado me.codigo_ibge),
    'analise.ideb_fund_ii',
    {populacao_estimada => 'populacao.populacao_estimada'},
    {latitude => 'ST_Y(ST_Centroid(me.geometry))'},
    {longitude => 'ST_X(ST_Centroid(me.geometry))'},
  ];

  my $results = $self->_search_unaccent($params->{term})
  ->limit($params->{limit} // 10)
  ->join('analise')->join('populacao')
  ->columns( $cols )
  ->as_hash->get_all;

  return $self->json->encode($results->to_array);
}

sub _search_unaccent($self, $term) {
  my $rs = $self->schema->resultset('MunicipiosSp');
  my $expr = q{contrib.unaccent(me.nome_municipio) ILIKE contrib.unaccent(?)};
  return $rs->search_rs(\[$expr, $self->_wrap_percent($term)]);
}

sub find_schools($self,$cod) {
  my $tel = q<CONCAT('(', nu_ddd,')',' ', nu_telefone)>;
  my $end = q<CONCAT_WS(' ', ds_endereco, nu_endereco, no_bairro, '-', co_cep)>;

  my $attrs = {
    escola => 'no_entidade',
    municipio => 'no_municipio', 
    telefone => \$tel,
    codigo_inep => 'co_entidade',
    endereco => \$end,
  };

  my $rs = $self->schema->resultset('CensoEscolas')
  ->search_rs({ co_municipio => $cod })
  ->not_null('geometry')
  ->geojson_features('geometry', $attrs);

  return $rs->get_column('feature')->first || 'null';
}

sub _wrap_percent($self, $value) {
  croak "No value to wrap" unless $value;
  my $saned = ($value =~ s/[%']//gr);
  return "%$saned%";
}

1;

__END__

=pod

=head1 NAME

EduMaps::Model::City - Modelo para Cidades no EduMaps

=head1 DESCRIPTION

O Modelo representa os dados geográficos, econômicos, demográficos e educacionais relacionados
a municipalidades.

=head1 AUTHOR

EduMaps Development Team

=head1 COPYRIGHT

Copyright (c) 2024 EduMaps. All rights reserved.

=cut
