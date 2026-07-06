package EduMaps::Roles::DB::Geo;
use Mojo::Base -role, -signatures;

requires qw(search_rs);

sub geojson_features($self, $geom, $properties) {
  my $attrs = ref $properties eq 'ARRAY' ?
  [ map { ("'$_'", $_) } @$properties ]
  :
  [ map { ("'$_'", $properties->{$_})} keys %$properties ];

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
                      \"ST_AsGeoJSON($geom)::json",
                      qw('properties'),
                      { json_build_object =>  $attrs }
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
