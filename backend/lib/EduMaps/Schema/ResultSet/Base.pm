package EduMaps::Schema::ResultSet::Base;
use Mojo::Base 'DBIx::Class::ResultSet', -signatures;
use Role::Tiny::With;
our @APP_ROLES = map { "MyApp::Roles::$_" } qw(PrettyPrint Formats);
with @APP_ROLES;

# full qualified column name
sub fqcn( $self, %spec ) {
  my $me  = $spec{relation} // $self->current_source_alias;
  my $col = $spec{column};
  return "$me.$col";
}

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
