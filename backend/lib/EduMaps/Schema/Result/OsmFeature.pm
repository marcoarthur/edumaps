use utf8;
package EduMaps::Schema::Result::OsmFeature;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

EduMaps::Schema::Result::OsmFeature - Features OSM generalizadas (node/way/relation)

=head1 DESCRIPTION

Uma feição do OpenStreetMap em qualquer tipo (node, way ou relation), com
geometria em SIRGAS 2000 (SRID 4674) e as tags completas em JSONB. Substitui
o antigo C<clean.osm_landuse> (que só guardava C<way>): a chave primária é
composta por C<(osm_type, osm_id)> porque os ids colidem entre tipos.

=cut

__PACKAGE__->table("clean.osm_feature");

__PACKAGE__->add_columns(
  "osm_type",
  { data_type => "text", is_nullable => 0 },
  "osm_id",
  { data_type => "bigint", is_nullable => 0 },
  "tags_key",
  { data_type => "text", is_nullable => 1 },
  "tags_value",
  { data_type => "text", is_nullable => 1 },
  "category",
  { data_type => "text", is_nullable => 1 },
  "geom",
  { data_type => "geometry", is_nullable => 1 },
  "properties",
  { data_type => "jsonb", is_nullable => 1 },
  "created_at",
  { data_type => "timestamp with time zone", is_nullable => 1, default_value => \"now()" },
  "updated_at",
  { data_type => "timestamp with time zone", is_nullable => 1, default_value => \"now()" },
);

__PACKAGE__->set_primary_key("osm_type", "osm_id");

__PACKAGE__->has_many(
  "osm_query_features",
  "EduMaps::Schema::Result::OsmQueryFeature",
  {
    "foreign.osm_type" => "self.osm_type",
    "foreign.osm_id"   => "self.osm_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "school_osm_features",
  "EduMaps::Schema::Result::SchoolOsmFeature",
  {
    "foreign.osm_type" => "self.osm_type",
    "foreign.osm_id"   => "self.osm_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "municipio_osm_features",
  "EduMaps::Schema::Result::MunicipioOsmFeature",
  {
    "foreign.osm_type" => "self.osm_type",
    "foreign.osm_id"   => "self.osm_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

1;
