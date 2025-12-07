use utf8;
package EduMaps::Schema::Result::OsmQuery;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::OsmQuery

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.osm_query>

=cut

__PACKAGE__->table("clean.osm_query");

=head1 ACCESSORS

=head2 digest

  data_type: 'text'
  is_nullable: 0

=head2 query

  data_type: 'text'
  is_nullable: 0

=head2 last_run

  data_type: 'timestamp'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 elapsed_time

  data_type: 'double precision'
  is_nullable: 1

=head2 raw_results

  data_type: 'json'
  is_nullable: 1

=head2 city_fid

  data_type: 'varchar'
  is_nullable: 0
  size: 7

=cut

__PACKAGE__->add_columns(
  "digest",
  { data_type => "text", is_nullable => 0 },
  "query",
  { data_type => "text", is_nullable => 0 },
  "last_run",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "elapsed_time",
  { data_type => "double precision", is_nullable => 1 },
  "raw_results",
  { data_type => "json", is_nullable => 1 },
  "city_fid",
  { data_type => "varchar", is_nullable => 0, size => 7 },
);

=head1 PRIMARY KEY

=over 4

=item * L</digest>

=back

=cut

__PACKAGE__->set_primary_key("digest");

=head1 RELATIONS

=head2 osm_landuses

Type: has_many

Related object: L<EduMaps::Schema::Result::OsmLanduse>

=cut

__PACKAGE__->has_many(
  "osm_landuses",
  "EduMaps::Schema::Result::OsmLanduse",
  { "foreign.osm_query_id" => "self.digest" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-07 06:50:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9jpOam0R+NmEMH6XkY/lIg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
