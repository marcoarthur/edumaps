use utf8;
package EduMaps::Schema::Result::ConsistentSchools;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::ConsistentSchools

=head1 DESCRIPTION

Escolas consistentes: participaram de todas as avaliações d
  isponíveis para sua etapa.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.consistent_schools>

=cut

__PACKAGE__->table("clean.consistent_schools");

=head1 ACCESSORS

=head2 id_escola

  data_type: 'bigint'
  is_nullable: 1

Código único da escola (INEP)

=head2 no_escola

  data_type: 'varchar'
  is_nullable: 1
  size: 200

Nome da escola

=head2 sg_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Sigla da Unidade da Federação

=head2 rede

  data_type: 'varchar'
  is_nullable: 1
  size: 30

Rede de ensino (Municipal, Estadual, Privada, Federal)

=head2 etapa

  data_type: 'varchar'
  is_nullable: 1
  size: 15

Etapa de ensino (fundamental_ii ou ensino_medio)

=head2 anos_participou

  data_type: 'bigint'
  is_nullable: 1

Número de anos em que a escola possui IDEB observado

=head2 total_anos

  data_type: 'bigint'
  is_nullable: 1

Número total de anos disponíveis na base para a respectiva 
  etapa

=cut

__PACKAGE__->add_columns(
  "id_escola",
  { data_type => "bigint", is_nullable => 1 },
  "no_escola",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "sg_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "rede",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "etapa",
  { data_type => "varchar", is_nullable => 1, size => 15 },
  "anos_participou",
  { data_type => "bigint", is_nullable => 1 },
  "total_anos",
  { data_type => "bigint", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-12 18:01:17
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:euTDS+yuW/y00Zh4eQeyyw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
