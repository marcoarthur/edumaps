use utf8;
package MyApp::Schema::Result::Country;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MyApp::Schema::Result::Country

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<countries>

=cut

__PACKAGE__->table("countries");

=head1 ACCESSORS

=head2 id

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

=head2 name

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

=head2 geog

  data_type: 'geography'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "name",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "geog",
  { data_type => "geography", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-09-26 08:26:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jNluvf2GjsbyyOsCK+ZXXg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
