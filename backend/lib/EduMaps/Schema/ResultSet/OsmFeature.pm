package EduMaps::Schema::ResultSet::OsmFeature;

use Mojo::Base 'EduMaps::Schema::ResultSet::Base', -signatures;

=head1 NAME

EduMaps::Schema::ResultSet::OsmFeature - ResultSet das features OSM

=cut

sub feat_collection($self) {
  $self->geojson_features(
    'geom',
    [qw(osm_type osm_id tags_key tags_value category properties)]
  );
}

1;
