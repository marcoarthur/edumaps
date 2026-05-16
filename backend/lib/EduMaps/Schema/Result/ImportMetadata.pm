use utf8;
package EduMaps::Schema::Result::ImportMetadata;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::ImportMetadata

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.import_metadata>

=cut

__PACKAGE__->table("clean.import_metadata");

=head1 ACCESSORS

=head2 id_import

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'import_metadata_id_import_seq'

=head2 table_name

  data_type: 'text'
  is_nullable: 0

=head2 source_file

  data_type: 'text'
  is_nullable: 0

=head2 import_timestamp

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 1
  original: {default_value => \"now()"}

=head2 row_count_loaded

  data_type: 'bigint'
  is_nullable: 1

=head2 notes

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id_import",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "import_metadata_id_import_seq",
  },
  "table_name",
  { data_type => "text", is_nullable => 0 },
  "source_file",
  { data_type => "text", is_nullable => 0 },
  "import_timestamp",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
  "row_count_loaded",
  { data_type => "bigint", is_nullable => 1 },
  "notes",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_import>

=back

=cut

__PACKAGE__->set_primary_key("id_import");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-16 16:27:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:qrSJr28tinNqri21SZJm7A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
