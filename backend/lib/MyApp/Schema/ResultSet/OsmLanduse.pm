package MyApp::Schema::ResultSet::OsmLanduse;
use Mojo::Base 'MyApp::Schema::ResultSet::Base', -signatures;

sub feat_collection($self) {
  $self->geojson_features(
    'geom',
    [qw(properties)]
  );
}

1;
