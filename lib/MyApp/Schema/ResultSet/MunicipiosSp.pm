package MyApp::Schema::ResultSet::MunicipiosSp;
use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use Role::Tiny::With;
with qw(MyApp::Roles::PrettyPrint);

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
  $self->search_rs(
    undef,
    {
      select => [
        {
          json_build_object => [
            qw('type' 'FeatureCollection' 'features'),
            { coalesce => 
              [
                { 
                  json_agg => { 
                    json_build_object => [
                      qw('type' 'Feature' 'geometry'),
                      \"ST_AsGeoJSON(geog)::json",
                      qw('properties'),
                      { json_build_object => [qw('name'), 'nm_mun', qw('area'), 'area_km2', qw('fid'), 'fid'] }
                    ]
                  } 
                },
                \"'[]'::json"
              ]
            }
          ],
          -as => 'feature',
        }
      ],
      as => ['feature'],
    }
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
  ];
  my @params = ( 
    { fid => $id }, 
    { 
      columns => $cols,
      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    }
  );
  $self->search_rs( @params );
}

1;
