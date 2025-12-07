use utf8;
package EduMaps::Schema::Result::MunicipiosSp;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::MunicipiosSp

=head1 DESCRIPTION

Dados limpos de municípios de São Paulo (IBGE 2024) com nomenclatura semântica e geometrias validadas

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<clean.municipios_sp>

=cut

__PACKAGE__->table("clean.municipios_sp");

=head1 ACCESSORS

=head2 id_original

  data_type: 'bigint'
  is_nullable: 1

ID original do shapefile (fid)

=head2 codigo_ibge

  data_type: 'varchar'
  is_nullable: 0
  size: 7

Código oficial do IBGE para o município

=head2 nome

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do município

=head2 nome_municipio

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome completo do município (redundante para compatibilidade)

=head2 codigo_regiao_imediata

  data_type: 'varchar'
  is_nullable: 1
  size: 6

Código da região imediata according to IBGE

=head2 nome_regiao_imediata

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da região imediata

=head2 codigo_regiao_intermediaria

  data_type: 'varchar'
  is_nullable: 1
  size: 4

Código da região intermediária

=head2 nome_regiao_intermediaria

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome da região intermediária

=head2 codigo_uf

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Código da Unidade Federativa

=head2 nome_estado

  data_type: 'varchar'
  is_nullable: 1
  size: 50

Nome do estado

=head2 sigla_estado

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Sigla do estado (SP)

=head2 codigo_regiao

  data_type: 'varchar'
  is_nullable: 1
  size: 1

Código da região geográfica

=head2 nome_regiao

  data_type: 'varchar'
  is_nullable: 1
  size: 20

Nome da região geográfica

=head2 sigla_regiao

  data_type: 'varchar'
  is_nullable: 1
  size: 2

Sigla da região geográfica

=head2 codigo_concurso

  data_type: 'varchar'
  is_nullable: 1
  size: 7

Código do concurso (campo específico IBGE)

=head2 nome_concurso

  data_type: 'varchar'
  is_nullable: 1
  size: 100

Nome do concurso (campo específico IBGE)

=head2 area_km2

  data_type: 'double precision'
  is_nullable: 1

Área do município em quilômetros quadrados

=head2 geometry

  data_type: 'geometry'
  is_nullable: 1
  size: '16916,18'

Geometria do município em MULTIPOLYGON (SRID 4674)

=head2 geometria_corrigida

  data_type: 'boolean'
  is_nullable: 1

Indica se a geometria original foi corrigida com ST_MakeValid

=head2 codigo_ibge_antigo

  data_type: 'varchar'
  is_nullable: 1
  size: 6

Código IBGE antigo (6 dígitos) - primeiros 6 dígitos do código oficial de 7 dígitos

=cut

__PACKAGE__->add_columns(
  "id_original",
  { data_type => "bigint", is_nullable => 1 },
  "codigo_ibge",
  { data_type => "varchar", is_nullable => 0, size => 7 },
  "nome",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "nome_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "codigo_regiao_imediata",
  { data_type => "varchar", is_nullable => 1, size => 6 },
  "nome_regiao_imediata",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "codigo_regiao_intermediaria",
  { data_type => "varchar", is_nullable => 1, size => 4 },
  "nome_regiao_intermediaria",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "codigo_uf",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "nome_estado",
  { data_type => "varchar", is_nullable => 1, size => 50 },
  "sigla_estado",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "codigo_regiao",
  { data_type => "varchar", is_nullable => 1, size => 1 },
  "nome_regiao",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "sigla_regiao",
  { data_type => "varchar", is_nullable => 1, size => 2 },
  "codigo_concurso",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "nome_concurso",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "area_km2",
  { data_type => "double precision", is_nullable => 1 },
  "geometry",
  { data_type => "geometry", is_nullable => 1, size => "16916,18" },
  "geometria_corrigida",
  { data_type => "boolean", is_nullable => 1 },
  "codigo_ibge_antigo",
  { data_type => "varchar", is_nullable => 1, size => 6 },
);

=head1 PRIMARY KEY

=over 4

=item * L</codigo_ibge>

=back

=cut

__PACKAGE__->set_primary_key("codigo_ibge");

=head1 RELATIONS

=head2 osm_landuses

Type: has_many

Related object: L<EduMaps::Schema::Result::OsmLanduse>

=cut

__PACKAGE__->has_many(
  "osm_landuses",
  "EduMaps::Schema::Result::OsmLanduse",
  { "foreign.municipio_id" => "self.codigo_ibge" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2025-12-07 06:50:16
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:D+d1k4nqBtmrJ5rZxDl7kg


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->has_one(
  'populacao',
  'EduMaps::Schema::Result::PopulacaoMunicipal',
  { 'foreign.codigo_ibge' => 'self.codigo_ibge' },
);

__PACKAGE__->has_many(
  'inep_info',
  'EduMaps::Schema::Result::Inep',
  {'foreign.codigo_ibge' => 'self.codigo_ibge' },
);

__PACKAGE__->has_many(
  'escolas',
  'EduMaps::Schema::Result::Escolas',
  sub {
    my $args = shift;
    my ($foreign_a, $self_a) = ($args->{foreign_alias}, $args->{self_alias});
    my $on_join_clause = sprintf "ST_Contains(%s.geometry::geometry, %s.geometry)", $self_a, $foreign_a;
    return \[$on_join_clause];
  },
  { join_type => 'LEFT' },
);

__PACKAGE__->has_one(
  'analise_cobertura',
  'EduMaps::Schema::Result::AnaliseCoberturaEscolar',
  {'foreign.codigo_ibge' => 'self.codigo_ibge'}
);

1;
