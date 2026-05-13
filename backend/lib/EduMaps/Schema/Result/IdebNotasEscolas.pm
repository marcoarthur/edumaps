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
  size: [undef,"ARRAY(0x5605fa9c64b8)"]

Indicador de rendimento (0-1) - Taxa de aprovação ajustada

=head2 aprovacao_1

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa8bafa0)"]

Taxa de aprovação da 1ª série/ano (%)

=head2 aprovacao_2

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa660640)"]

Taxa de aprovação da 2ª série/ano (%)

=head2 aprovacao_3

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa457578)"]

Taxa de aprovação da 3ª série/ano (%)

=head2 aprovacao_4

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa048948)"]

Taxa de aprovação da 4ª série/ano (%) - aplicável ao ensino médio

=head2 nota_matematica

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa155308)"]

Proficiência média em Matemática (escala SAEB)

=head2 nota_portugues

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa9a0d18)"]

Proficiência média em Língua Portuguesa (escala SAEB)

=head2 nota_media

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fae32a78)"]

Média das proficiências em Matemática e Português

=head2 ideb_observado

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa514d58)"]

IDEB observado no ano

=head2 ideb_projecao

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x5605fa667260)"]

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
    size => [undef, "ARRAY(0x5605fa9c64b8)"],
  },
  "aprovacao_1",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa8bafa0)"],
  },
  "aprovacao_2",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa660640)"],
  },
  "aprovacao_3",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa457578)"],
  },
  "aprovacao_4",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa048948)"],
  },
  "nota_matematica",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa155308)"],
  },
  "nota_portugues",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa9a0d18)"],
  },
  "nota_media",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fae32a78)"],
  },
  "ideb_observado",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa514d58)"],
  },
  "ideb_projecao",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x5605fa667260)"],
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


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-13 15:42:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:gvmb+rGCopSqNnyURJO0xQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.id_escola' },
);

1;
