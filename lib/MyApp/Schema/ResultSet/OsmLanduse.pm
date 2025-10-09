package MyApp::Schema::ResultSet::OsmLanduse;
use Mojo::Base 'MyApp::Schema::ResultSet::Base', -signatures;

sub feat_collection($self) {
  $self->geojson_features(
    'geom',
    [qw(osm_id osm_query_id)]
  );
}

1;
