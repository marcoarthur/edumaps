use utf8;
package EduMaps::Schema::Result::IdebNotasEscolas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::IdebNotasEscolas

=head1 DESCRIPTION

Dados do IDEB/SAEB para escolas brasileiras (2005-2023), incluindo aprovações, notas de proficiência e indicadores de qualidade para todas as etapas: fundamental I, fundamental II e ensino médio

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.ideb_notas_escolas>

=cut

__PACKAGE__->table("clean.ideb_notas_escolas");

=head1 ACCESSORS

=head2 id_escola

  data_type: 'bigint'
  is_nullable: 0

Código único da escola (INEP) - corresponde ao co_entidade do censo escolar

=head2 sg_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Sigla da Unidade da Federação

=head2 co_municipio

  data_type: 'integer'
  is_nullable: 1

Código do município (IBGE)

=head2 no_municipio

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do município

=head2 no_escola

  data_type: 'varchar'
  is_nullable: 1
  size: 200

Nome da escola

=head2 rede

  data_type: 'varchar'
  is_nullable: 1
  size: 30

Rede de ensino (Municipal, Estadual, Privada, Federal)

=head2 ano

  data_type: 'integer'
  is_nullable: 0

Ano de referência dos dados

=head2 etapa

  data_type: 'varchar'
  is_nullable: 0
  size: 15

Etapa de ensino (fundamental_ii ou ensino_medio)

=head2 aprovacao_si_4

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131c5a3c00)"]

Indicador de rendimento (0-1) - Taxa de aprovação ajustada

=head2 aprovacao_1

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131ba2ff18)"]

Taxa de aprovação da 1ª série/ano (%)

=head2 aprovacao_2

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131b81f880)"]

Taxa de aprovação da 2ª série/ano (%)

=head2 aprovacao_3

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131bfa5ab0)"]

Taxa de aprovação da 3ª série/ano (%)

=head2 aprovacao_4

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131bd9d838)"]

Taxa de aprovação da 4ª série/ano (%) - aplicável ao ensino médio

=head2 nota_matematica

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131ba8e448)"]

Proficiência média em Matemática (escala SAEB)

=head2 nota_portugues

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131bce2f50)"]

Proficiência média em Língua Portuguesa (escala SAEB)

=head2 nota_media

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131c069be0)"]

Média das proficiências em Matemática e Português

=head2 ideb_observado

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131bb19d88)"]

IDEB observado no ano

=head2 ideb_projecao

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x56131bd41f80)"]

Meta IDEB projetada para o ano

=cut

__PACKAGE__->add_columns(
  "id_escola",
  { data_type => "bigint", is_nullable => 0 },
  "sg_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "co_municipio",
  { data_type => "integer", is_nullable => 1 },
  "no_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "no_escola",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "rede",
  { data_type => "varchar", is_nullable => 1, size => 30 },
  "ano",
  { data_type => "integer", is_nullable => 0 },
  "etapa",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "aprovacao_si_4",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131c5a3c00)"],
  },
  "aprovacao_1",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131ba2ff18)"],
  },
  "aprovacao_2",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131b81f880)"],
  },
  "aprovacao_3",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131bfa5ab0)"],
  },
  "aprovacao_4",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131bd9d838)"],
  },
  "nota_matematica",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131ba8e448)"],
  },
  "nota_portugues",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131bce2f50)"],
  },
  "nota_media",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131c069be0)"],
  },
  "ideb_observado",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131bb19d88)"],
  },
  "ideb_projecao",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x56131bd41f80)"],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id_escola>

=item * L</etapa>

=item * L</ano>

=back

=cut

__PACKAGE__->set_primary_key("id_escola", "etapa", "ano");


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-18 15:25:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vs1d5Tfg64XL3tEqYx2wow


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.id_escola' },
);

1;
