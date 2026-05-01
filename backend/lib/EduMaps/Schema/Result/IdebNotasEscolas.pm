use utf8;
package EduMaps::Schema::Result::IdebNotasEscolas;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::IdebNotasEscolas

=head1 DESCRIPTION

Dados do IDEB/SAEB para escolas brasileiras (2005-2023), incluindo aprovações, notas de proficiência e indicadores de qualidade

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ideb_notas_escolas>

=cut

__PACKAGE__->table("ideb_notas_escolas");

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
  size: [undef,"ARRAY(0x556d91a2e358)"]

Indicador de rendimento (0-1) - Taxa de aprovação ajustada

=head2 aprovacao_1

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d92055158)"]

Taxa de aprovação da 1ª série/ano (%)

=head2 aprovacao_2

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d92788660)"]

Taxa de aprovação da 2ª série/ano (%)

=head2 aprovacao_3

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d91bbf2b0)"]

Taxa de aprovação da 3ª série/ano (%)

=head2 aprovacao_4

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d91c42170)"]

Taxa de aprovação da 4ª série/ano (%) - aplicável ao ensino médio

=head2 nota_matematica

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d91c850d0)"]

Proficiência média em Matemática (escala SAEB)

=head2 nota_portugues

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d91c8ba60)"]

Proficiência média em Língua Portuguesa (escala SAEB)

=head2 nota_media

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d91ea79a0)"]

Média das proficiências em Matemática e Português

=head2 ideb_observado

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d922b08c8)"]

IDEB observado no ano

=head2 ideb_projecao

  data_type: 'numeric'
  is_nullable: 1
  size: [undef,"ARRAY(0x556d920fbbc8)"]

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
    size => [undef, "ARRAY(0x556d91a2e358)"],
  },
  "aprovacao_1",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d92055158)"],
  },
  "aprovacao_2",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d92788660)"],
  },
  "aprovacao_3",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d91bbf2b0)"],
  },
  "aprovacao_4",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d91c42170)"],
  },
  "nota_matematica",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d91c850d0)"],
  },
  "nota_portugues",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d91c8ba60)"],
  },
  "nota_media",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d91ea79a0)"],
  },
  "ideb_observado",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d922b08c8)"],
  },
  "ideb_projecao",
  {
    data_type => "numeric",
    is_nullable => 1,
    size => [undef, "ARRAY(0x556d920fbbc8)"],
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


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-04-30 16:33:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:G3lZ20/TIyZq1ssASqDvFw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.id_escola' },
);

1;
