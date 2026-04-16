use utf8;
package EduMaps::Schema::Result::OsmLanduse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::OsmLanduse

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<osm_landuse>

=cut

__PACKAGE__->table("osm_landuse");

=head1 ACCESSORS

=head2 osm_id

  data_type: 'bigint'
  is_nullable: 0

=head2 municipio_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 7

=head2 osm_query_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 1

=head2 geom

  data_type: 'geometry'
  is_nullable: 1
  size: [18,16892]

=head2 properties

  data_type: 'jsonb'
  is_nullable: 1

=head2 land_use

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "osm_id",
  { data_type => "bigint", is_nullable => 0 },
  "municipio_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 7 },
  "osm_query_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
  "geom",
  { data_type => "geometry", is_nullable => 1, size => [18, 16892] },
  "properties",
  { data_type => "jsonb", is_nullable => 1 },
  "land_use",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</osm_id>

=back

=cut

__PACKAGE__->set_primary_key("osm_id");

=head1 RELATIONS

=head2 municipio

Type: belongs_to

Related object: L<EduMaps::Schema::Result::MunicipiosSp>

=cut

__PACKAGE__->belongs_to(
  "municipio",
  "EduMaps::Schema::Result::MunicipiosSp",
  { codigo_ibge => "municipio_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 osm_query

Type: belongs_to

Related object: L<EduMaps::Schema::Result::OsmQuery>

=cut

__PACKAGE__->belongs_to(
  "osm_query",
  "EduMaps::Schema::Result::OsmQuery",
  { digest => "osm_query_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-16 10:52:18
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:a2bw2k1PUkqMq8JBsVyrLw


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->might_have(
  'escolas',
  'EduMaps::Schema::Result::Escolas',
  sub {
    my $args = shift;
    my $radius = 1000;
    my ($foreign_a, $self_a) = ($args->{foreign_alias}, $args->{self_alias});
    my $on_join_clause = sprintf 
    "ST_DWithin(%s.geom::geography, %s.geometry::geography, $radius)", 
    $self_a, $foreign_a;
    return \[$on_join_clause];
  }
);

1;
