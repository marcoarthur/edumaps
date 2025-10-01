package MyApp::Schema::ResultSet::MunicipiosSp;
use Mojo::Base 'MyApp::Schema::ResultSet::Base', -signatures;

sub with_geojson($self) {

  $self->search_rs(
    undef,
    {
      '+select' => [ {ST_AsGeoJSON => 'geog', -as => 'geojson'} ],
      '+as'     => [ qw/geojson/],
    }
  );
}

sub feat_collection($self) {
  $self->geojson_features(
    'geog',
    { name => 'nm_mun', area => 'area_km2', fid => 'fid' }
  );
}

sub details($self,$id) {
  my $cols = [
    { id => 'fid' },
    { codigo_municipio => 'cd_mun' },
    { nome_municipio => 'nm_mun' },
    { nome_regiao_intermediaria => 'nm_rgi' },
    { nome_regiao_interna => 'nm_rgint' },
    { codigo_unidade_federativa => 'cd_uf' },
    { nome_unidade_federativa => 'nm_uf' },
    { sigla_unidade_federativa => 'sigla_uf' },
    { codigo_regiao => 'cd_regia' },
    { sigla_regiao => 'sigla_rg' },
    { codigo_concurso => 'cd_concu' },
    { nome_concurso => 'nm_concu' },
    { area => 'area_km2' },
    { total_escolas => { count => 'escolas' } },
  ];
  my @params = ( 
    { fid => $id }, 
    { 
      join => ['escolas'],
      columns => $cols,
      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
      group_by => 'fid',
    }
  );
  $self->search_rs( @params );
}

1;
