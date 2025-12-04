use utf8;
package EduMaps::Schema::Result::MetricasAcessibilidadeMunicipios;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::MetricasAcessibilidadeMunicipios

=head1 DESCRIPTION

View materializada com métricas de acessibilidade escolar por município (raio 5km)

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.metricas_acessibilidade_municipios>

=cut

__PACKAGE__->table("analytics.metricas_acessibilidade_municipios");

=head1 ACCESSORS

=head2 codigo_ibge

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

=head2 municipio

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

=head2 percentual_cobertura

  data_type: 'double precision'
  is_nullable: 1

=head2 area_coberta_km2

  data_type: 'double precision'
  is_nullable: 1

=head2 area_total_km2

  data_type: 'double precision'
  is_nullable: 1

=head2 n_escolas

  data_type: 'bigint'
  is_nullable: 1

=head2 densidade_escolas_km2

  data_type: 'double precision'
  is_nullable: 1

=head2 area_coberta_por_escola

  data_type: 'double precision'
  is_nullable: 1

=head2 categoria_cobertura

  data_type: 'text'
  is_nullable: 1

=head2 atualizado_em

  data_type: 'timestamp with time zone'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "codigo_ibge",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "municipio",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "percentual_cobertura",
  { data_type => "double precision", is_nullable => 1 },
  "area_coberta_km2",
  { data_type => "double precision", is_nullable => 1 },
  "area_total_km2",
  { data_type => "double precision", is_nullable => 1 },
  "n_escolas",
  { data_type => "bigint", is_nullable => 1 },
  "densidade_escolas_km2",
  { data_type => "double precision", is_nullable => 1 },
  "area_coberta_por_escola",
  { data_type => "double precision", is_nullable => 1 },
  "categoria_cobertura",
  { data_type => "text", is_nullable => 1 },
  "atualizado_em",
  { data_type => "timestamp with time zone", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_metricas_acessibilidade_codigo>

=over 4

=item * L</codigo_ibge>

=back

=cut

__PACKAGE__->add_unique_constraint("idx_metricas_acessibilidade_codigo", ["codigo_ibge"]);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-03 21:38:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:pcKKXZ/s4al6GTm2r/yz7Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
