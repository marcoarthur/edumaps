use utf8;
package MyApp::Schema::Result::MunicipiosSp;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MyApp::Schema::Result::MunicipiosSp

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<municipios_sp>

=cut

__PACKAGE__->table("municipios_sp");

=head1 ACCESSORS

=head2 fid

  data_type: 'bigint'
  is_nullable: 0

=head2 geog

  data_type: 'geography'
  is_nullable: 1
  size: '16916,18'

=head2 cd_mun

  data_type: 'varchar'
  is_nullable: 1
  size: 7

=head2 nm_mun

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 cd_rgi

  data_type: 'varchar'
  is_nullable: 1
  size: 6

=head2 nm_rgi

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 cd_rgint

  data_type: 'varchar'
  is_nullable: 1
  size: 4

=head2 nm_rgint

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 cd_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

=head2 nm_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 50

=head2 sigla_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

=head2 cd_regia

  data_type: 'varchar'
  is_nullable: 1
  size: 1

=head2 nm_regia

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 sigla_rg

  data_type: 'varchar'
  is_nullable: 1
  size: 2

=head2 cd_concu

  data_type: 'varchar'
  is_nullable: 1
  size: 7

=head2 nm_concu

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 area_km2

  data_type: 'double precision'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "fid",
  { data_type => "bigint", is_nullable => 0 },
  "geog",
  { data_type => "geography", is_nullable => 1, size => "16916,18" },
  "cd_mun",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "nm_mun",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "cd_rgi",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "nm_rgi",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "cd_rgint",
  { data_type => "varchar", is_nullable => 1, size => 4 },
  "nm_rgint",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "cd_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "nm_uf",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "sigla_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "cd_regia",
  { data_type => "varchar", is_nullable => 1, size => 1 },
  "nm_regia",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "sigla_rg",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "cd_concu",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "nm_concu",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "area_km2",
  { data_type => "double precision", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</fid>

=back

=cut

__PACKAGE__->set_primary_key("fid");

=head1 RELATIONS

=head2 osm_landuses

Type: has_many

Related object: L<MyApp::Schema::Result::OsmLanduse>

=cut

__PACKAGE__->has_many(
  "osm_landuses",
  "MyApp::Schema::Result::OsmLanduse",
  { "foreign.municipio_id" => "self.fid" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-10-05 12:03:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PFgIKKs1PbWljB99IXSXzg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->has_many(
  'escolas', # This will be the relationship name
  'MyApp::Schema::Result::Escola', # The related Result class
  sub {
    my $args = shift;
    my $f_alias = $args->{foreign_alias};
    my $s_alias = $args->{self_alias};
    my $on_clause = sprintf "ST_Contains(%s.geog::geometry, %s.geom)", $s_alias, $f_alias;

    return \["$on_clause"];
  },
);

1;
