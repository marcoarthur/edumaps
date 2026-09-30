use utf8;
package EduMaps::Schema::Result::CensoDataDictionary;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoDataDictionary

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.censo_data_dictionary>

=cut

__PACKAGE__->table("clean.censo_data_dictionary");

=head1 ACCESSORS

=head2 table_name

  data_type: 'text'
  is_nullable: 0

=head2 column_name

  data_type: 'text'
  is_nullable: 0

=head2 data_type

  data_type: 'text'
  is_nullable: 0

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 value_domain

  data_type: 'jsonb'
  is_nullable: 1

=head2 year_introduced

  data_type: 'smallint'
  is_nullable: 0

=head2 year_changed

  data_type: 'smallint'
  is_nullable: 1

=head2 year_deprecated

  data_type: 'smallint'
  is_nullable: 1

=head2 is_pk

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 is_fk

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 fk_target_table

  data_type: 'text'
  is_nullable: 1

=head2 fk_target_column

  data_type: 'text'
  is_nullable: 1

=head2 source_file

  data_type: 'text'
  is_nullable: 1

=head2 source_url

  data_type: 'text'
  is_nullable: 1

=head2 source_license

  data_type: 'text'
  is_nullable: 1

=head2 retrieved_at

  data_type: 'timestamp with time zone'
  is_nullable: 1

=head2 notes

  data_type: 'text'
  is_nullable: 1

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => "now()"}

=head2 updated_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0
  original: {default_value => "now()"}

=cut

__PACKAGE__->add_columns(
  "table_name",
  { data_type => "text", is_nullable => 0 },
  "column_name",
  { data_type => "text", is_nullable => 0 },
  "data_type",
  { data_type => "text", is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "value_domain",
  { data_type => "jsonb", is_nullable => 1 },
  "year_introduced",
  { data_type => "smallint", is_nullable => 0 },
  "year_changed",
  { data_type => "smallint", is_nullable => 1 },
  "year_deprecated",
  { data_type => "smallint", is_nullable => 1 },
  "is_pk",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_fk",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "fk_target_table",
  { data_type => "text", is_nullable => 1 },
  "fk_target_column",
  { data_type => "text", is_nullable => 1 },
  "source_file",
  { data_type => "text", is_nullable => 1 },
  "source_url",
  { data_type => "text", is_nullable => 1 },
  "source_license",
  { data_type => "text", is_nullable => 1 },
  "retrieved_at",
  { data_type => "timestamp with time zone", is_nullable => 1 },
  "notes",
  { data_type => "text", is_nullable => 1 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "updated_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</table_name>

=item * L</column_name>

=item * L</year_introduced>

=back

=cut

__PACKAGE__->set_primary_key("table_name", "column_name", "year_introduced");

# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-09-30 00:00:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:placeholder

1;