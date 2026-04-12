use utf8;
package EduMaps::Schema::Result::MunicipioSimilaridade;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::MunicipioSimilaridade

=head1 DESCRIPTION

Similaridade entre municípios baseada em salário médio, carga horária média e número de profissionais para o ano de 2024

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.municipio_similaridade>

=cut

__PACKAGE__->table("analytics.municipio_similaridade");

=head1 ACCESSORS

=head2 municipio_1

  data_type: 'varchar'
  is_nullable: 1
  size: 8

Código IBGE do primeiro município

=head2 municipio_2

  data_type: 'varchar'
  is_nullable: 1
  size: 8

Código IBGE do segundo município

=head2 distancia_euclidiana

  data_type: 'double precision'
  is_nullable: 1

Distância euclidiana entre os vetores de características dos municípios. Quanto menor, mais similares.

=head2 similaridade

  data_type: 'double precision'
  is_nullable: 1

Similaridade normalizada entre 0 e 1. Quanto mais próximo de 1, mais similares os municípios.

=cut

__PACKAGE__->add_columns(
  "municipio_1",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "municipio_2",
  { data_type => "varchar", is_nullable => 1, size => 8 },
  "distancia_euclidiana",
  { data_type => "double precision", is_nullable => 1 },
  "similaridade",
  { data_type => "double precision", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_municipio_similaridade_pair>

=over 4

=item * L</municipio_1>

=item * L</municipio_2>

=back

=cut

__PACKAGE__->add_unique_constraint(
  "idx_municipio_similaridade_pair",
  ["municipio_1", "municipio_2"],
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-12 13:44:21
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LxBkJ/yzBqra5/fbralMQQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
