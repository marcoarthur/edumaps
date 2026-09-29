use utf8;
package EduMaps::Schema::Result::SchoolOsmFeature;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

EduMaps::Schema::Result::SchoolOsmFeature - Relação escola <-> feature OSM (buffer)

=cut

__PACKAGE__->table("clean.school_osm_feature");

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 0 },
  "osm_type",
  { data_type => "text", is_nullable => 0 },
  "osm_id",
  { data_type => "bigint", is_nullable => 0 },
  "raio",
  { data_type => "integer", is_nullable => 0 },
  "distance_m",
  { data_type => "double precision", is_nullable => 1 },
  "digest",
  { data_type => "text", is_nullable => 1 },
  "created_at",
  { data_type => "timestamp with time zone", is_nullable => 1, default_value => \"now()" },
);

__PACKAGE__->set_primary_key("co_entidade", "nu_ano_censo", "osm_type", "osm_id");

__PACKAGE__->belongs_to(
  "osm_feature",
  "EduMaps::Schema::Result::OsmFeature",
  { "foreign.osm_type" => "self.osm_type", "foreign.osm_id" => "self.osm_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "NO ACTION" },
);

__PACKAGE__->belongs_to(
  "osm_query",
  "EduMaps::Schema::Result::OsmQuery",
  { digest => "digest" },
  { is_deferrable => 0, join_type => "LEFT", on_delete => "SET NULL", on_update => "NO ACTION" },
);

1;
