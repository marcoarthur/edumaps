use utf8;
package MyApp::Schema::Result::OsmLanduse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MyApp::Schema::Result::OsmLanduse

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

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 osm_query_id

  data_type: 'text'
  is_foreign_key: 1
  is_nullable: 1

=head2 geom

  data_type: 'geometry'
  is_nullable: 1
  size: '16892,18'

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
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "osm_query_id",
  { data_type => "text", is_foreign_key => 1, is_nullable => 1 },
  "geom",
  { data_type => "geometry", is_nullable => 1, size => "16892,18" },
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

Related object: L<MyApp::Schema::Result::MunicipiosSp>

=cut

__PACKAGE__->belongs_to(
  "municipio",
  "MyApp::Schema::Result::MunicipiosSp",
  { fid => "municipio_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 osm_query

Type: belongs_to

Related object: L<MyApp::Schema::Result::OsmQuery>

=cut

__PACKAGE__->belongs_to(
  "osm_query",
  "MyApp::Schema::Result::OsmQuery",
  { digest => "osm_query_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-10-08 21:36:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:RKsuoMpE85ImNtLoYMoetg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
