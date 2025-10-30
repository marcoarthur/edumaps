use utf8;
package EduMaps::Schema::Result::Country;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::Country

=head1 DESCRIPTION

Dados limpos de países com geometrias válidas em geography. Geometrias inválidas foram corrigidas com ST_MakeValid

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<countries>

=cut

__PACKAGE__->table("countries");

=head1 ACCESSORS

=head2 id

  data_type: 'bigint'
  is_nullable: 0

Identificador único gerado sequencialmente

=head2 name

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

Nome do país

=head2 geometry

  data_type: 'geography'
  is_nullable: 1

Geometria válida do país em formato geography (corrigida se necessário)

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "bigint", is_nullable => 0 },
  "name",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "geometry",
  { data_type => "geography", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-10-30 09:18:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:PQwk1Gg7vYngjfkx8EfuHw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
