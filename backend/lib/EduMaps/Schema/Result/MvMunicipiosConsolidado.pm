use utf8;
package EduMaps::Schema::Result::MvMunicipiosConsolidado;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::MvMunicipiosConsolidado

=head1 DESCRIPTION

VIEW MATERIALIZADA - Visão consolidada para análise municipal. Dados educacionais (Censo Escolar 2025), desempenho (IDEB/SAEB), demografia (IBGE) e economia (PIB). Materializada para performance em análises repetidas.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.mv_municipios_consolidado>

=cut

__PACKAGE__->table("analytics.mv_municipios_consolidado");

=head1 ACCESSORS

=head2 co_municipio

  data_type: 'text'
  is_nullable: 1

Código IBGE do município (7 dígitos)

=head2 no_municipio

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 sg_uf

  data_type: 'char'
  is_nullable: 1
  size: 2

=head2 no_regiao

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 total_escolas

  data_type: 'bigint'
  is_nullable: 1

Total de escolas no município

=head2 escolas_publicas

  data_type: 'bigint'
  is_nullable: 1

=head2 escolas_privadas

  data_type: 'bigint'
  is_nullable: 1

=head2 escolas_urbanas

  data_type: 'bigint'
  is_nullable: 1

=head2 escolas_rurais

  data_type: 'bigint'
  is_nullable: 1

=head2 total_alunos

  data_type: 'bigint'
  is_nullable: 1

Total de matrículas na educação básica

=head2 alunos_infantil

  data_type: 'bigint'
  is_nullable: 1

=head2 alunos_fundamental

  data_type: 'bigint'
  is_nullable: 1

=head2 alunos_medio

  data_type: 'bigint'
  is_nullable: 1

=head2 alunos_eja

  data_type: 'bigint'
  is_nullable: 1

=head2 total_docentes

  data_type: 'bigint'
  is_nullable: 1

Total de docentes na educação básica

=head2 perc_docentes_superior

  data_type: 'numeric'
  is_nullable: 1

=head2 perc_docentes_concursados

  data_type: 'numeric'
  is_nullable: 1

=head2 score_infra_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 score_tecnologia_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 score_acessibilidade_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 score_gestao_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 ideb_fund_i

  data_type: 'numeric'
  is_nullable: 1

=head2 ideb_fund_ii

  data_type: 'numeric'
  is_nullable: 1

IDEB dos anos finais do fundamental (último ano disponível)

=head2 ideb_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 ano_ideb

  data_type: 'integer'
  is_nullable: 1

=head2 populacao_estimada

  data_type: 'integer'
  is_nullable: 1

=head2 pop_0_a_14

  data_type: 'integer'
  is_nullable: 1

=head2 pop_15_a_24

  data_type: 'integer'
  is_nullable: 1

=head2 pop_25_a_59

  data_type: 'integer'
  is_nullable: 1

=head2 pop_60_mais

  data_type: 'integer'
  is_nullable: 1

=head2 pib_total

  data_type: 'numeric'
  is_nullable: 1

=head2 pib_per_capita

  data_type: 'numeric'
  is_nullable: 1

PIB per capita (em R$)

=head2 agro_percent

  data_type: 'numeric'
  is_nullable: 1

=head2 industria_percent

  data_type: 'numeric'
  is_nullable: 1

=head2 servicos_percent

  data_type: 'numeric'
  is_nullable: 1

=head2 governo_percent

  data_type: 'numeric'
  is_nullable: 1

=head2 ano_pib

  data_type: 'integer'
  is_nullable: 1

=head2 alunos_por_1000_hab

  data_type: 'numeric'
  is_nullable: 1

=head2 alunos_por_docente

  data_type: 'numeric'
  is_nullable: 1

Relação aluno-docente (municipal)

=head2 alunos_por_escola

  data_type: 'numeric'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "co_municipio",
  { data_type => "text", is_nullable => 1 },
  "no_municipio",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "sg_uf",
  { data_type => "char", is_nullable => 1, size => 2 },
  "no_regiao",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "total_escolas",
  { data_type => "bigint", is_nullable => 1 },
  "escolas_publicas",
  { data_type => "bigint", is_nullable => 1 },
  "escolas_privadas",
  { data_type => "bigint", is_nullable => 1 },
  "escolas_urbanas",
  { data_type => "bigint", is_nullable => 1 },
  "escolas_rurais",
  { data_type => "bigint", is_nullable => 1 },
  "total_alunos",
  { data_type => "bigint", is_nullable => 1 },
  "alunos_infantil",
  { data_type => "bigint", is_nullable => 1 },
  "alunos_fundamental",
  { data_type => "bigint", is_nullable => 1 },
  "alunos_medio",
  { data_type => "bigint", is_nullable => 1 },
  "alunos_eja",
  { data_type => "bigint", is_nullable => 1 },
  "total_docentes",
  { data_type => "bigint", is_nullable => 1 },
  "perc_docentes_superior",
  { data_type => "numeric", is_nullable => 1 },
  "perc_docentes_concursados",
  { data_type => "numeric", is_nullable => 1 },
  "score_infra_medio",
  { data_type => "numeric", is_nullable => 1 },
  "score_tecnologia_medio",
  { data_type => "numeric", is_nullable => 1 },
  "score_acessibilidade_medio",
  { data_type => "numeric", is_nullable => 1 },
  "score_gestao_medio",
  { data_type => "numeric", is_nullable => 1 },
  "ideb_fund_i",
  { data_type => "numeric", is_nullable => 1 },
  "ideb_fund_ii",
  { data_type => "numeric", is_nullable => 1 },
  "ideb_medio",
  { data_type => "numeric", is_nullable => 1 },
  "ano_ideb",
  { data_type => "integer", is_nullable => 1 },
  "populacao_estimada",
  { data_type => "integer", is_nullable => 1 },
  "pop_0_a_14",
  { data_type => "integer", is_nullable => 1 },
  "pop_15_a_24",
  { data_type => "integer", is_nullable => 1 },
  "pop_25_a_59",
  { data_type => "integer", is_nullable => 1 },
  "pop_60_mais",
  { data_type => "integer", is_nullable => 1 },
  "pib_total",
  { data_type => "numeric", is_nullable => 1 },
  "pib_per_capita",
  { data_type => "numeric", is_nullable => 1 },
  "agro_percent",
  { data_type => "numeric", is_nullable => 1 },
  "industria_percent",
  { data_type => "numeric", is_nullable => 1 },
  "servicos_percent",
  { data_type => "numeric", is_nullable => 1 },
  "governo_percent",
  { data_type => "numeric", is_nullable => 1 },
  "ano_pib",
  { data_type => "integer", is_nullable => 1 },
  "alunos_por_1000_hab",
  { data_type => "numeric", is_nullable => 1 },
  "alunos_por_docente",
  { data_type => "numeric", is_nullable => 1 },
  "alunos_por_escola",
  { data_type => "numeric", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_mv_municipios_co_municipio>

=over 4

=item * L</co_municipio>

=back

=cut

__PACKAGE__->add_unique_constraint("idx_mv_municipios_co_municipio", ["co_municipio"]);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-01 14:14:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0pPAYG4zqs/GViyhikLYDw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::ResultSet::MunicipiosSp',
  {'foreign.codigo_ibge' => 'self.co_municipio'},
  {join_type => 'INNER'},
);

1;
