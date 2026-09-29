use utf8;
package EduMaps::Schema::Result::SchoolOsmQuery;

use strict;
use warnings;
use base 'DBIx::Class::Core';

=head1 NAME

EduMaps::Schema::Result::SchoolOsmQuery - Seleção atual de POIs OSM por escola

=head1 DESCRIPTION

Guarda, por escola/ano do censo, o raio e os catálogos (perfis) da última
consulta OSM, além do digest da query e o carimbo de atualização. É o que
permite o upsert (sobrescrever a seleção anterior), o aviso de recência
(< 7 dias) e o status no Painel do Gestor.

=cut

__PACKAGE__->table("clean.school_osm_query");

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "bigint", is_nullable => 0 },
  "nu_ano_censo",
  { data_type => "integer", is_nullable => 0 },
  "raio",
  { data_type => "integer", is_nullable => 0 },
  "profiles",
  { data_type => "jsonb", is_nullable => 0 },
  "digest",
  { data_type => "text", is_nullable => 1 },
  "updated_at",
  { data_type => "timestamp with time zone", is_nullable => 1, default_value => \"now()" },
);

__PACKAGE__->set_primary_key("co_entidade", "nu_ano_censo");

__PACKAGE__->belongs_to(
  "osm_query",
  "EduMaps::Schema::Result::OsmQuery",
  { digest => "digest" },
  { is_deferrable => 0, join_type => "LEFT", on_delete => "SET NULL", on_update => "NO ACTION" },
);

1;
