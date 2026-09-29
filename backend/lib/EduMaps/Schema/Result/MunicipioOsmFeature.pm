use utf8;
package EduMaps::Schema::Result::MunicipioOsmFeature;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

EduMaps::Schema::Result::MunicipioOsmFeature - Relação município <-> feature OSM

=cut

__PACKAGE__->table("clean.municipio_osm_feature");

__PACKAGE__->add_columns(
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 0, size => 7 },
  "osm_type",
  { data_type => "text", is_nullable => 0 },
  "osm_id",
  { data_type => "bigint", is_nullable => 0 },
  "digest",
  { data_type => "text", is_nullable => 1 },
  "created_at",
  { data_type => "timestamp with time zone", is_nullable => 1, default_value => \"now()" },
);

__PACKAGE__->set_primary_key("codigo_ibge", "osm_type", "osm_id");

__PACKAGE__->belongs_to(
  "municipio",
  "EduMaps::Schema::Result::MunicipiosSp",
  { codigo_ibge => "codigo_ibge" },
  { is_deferrable => 0, join_type => "LEFT", on_delete => "NO ACTION", on_update => "NO ACTION" },
);

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
