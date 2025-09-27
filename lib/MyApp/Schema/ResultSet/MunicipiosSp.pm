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
                      { json_build_object => [qw('name'), 'nm_mun', qw('area'), 'area_km2'] }
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

1;
