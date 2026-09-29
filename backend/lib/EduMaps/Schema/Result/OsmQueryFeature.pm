use utf8;
package EduMaps::Schema::Result::OsmQueryFeature;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

EduMaps::Schema::Result::OsmQueryFeature - Proveniência (query OSM -> feature)

=cut

__PACKAGE__->table("clean.osm_query_feature");

__PACKAGE__->add_columns(
  "digest",
  { data_type => "text", is_nullable => 0 },
  "osm_type",
  { data_type => "text", is_nullable => 0 },
  "osm_id",
  { data_type => "bigint", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("digest", "osm_type", "osm_id");

__PACKAGE__->belongs_to(
  "osm_query",
  "EduMaps::Schema::Result::OsmQuery",
  { digest => "digest" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

__PACKAGE__->belongs_to(
  "osm_feature",
  "EduMaps::Schema::Result::OsmFeature",
  { "foreign.osm_type" => "self.osm_type", "foreign.osm_id" => "self.osm_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

1;
