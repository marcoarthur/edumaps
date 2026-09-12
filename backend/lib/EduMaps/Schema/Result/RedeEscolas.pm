use utf8;
package EduMaps::Schema::Result::RedeEscolas;

=head1 NAME

EduMaps::Schema::Result::RedeEscolas

=head1 DESCRIPTION

View materializada da rede de escolas por município e tipo de administração
(federal, estadual, municipal, privada), com matrículas e professores do Censo
Escolar 2025 e agregados de desempenho IDEB/SAEB (último ano por etapa).
Atualizar com `SELECT analytics.refresh_rede_escolas()`.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.mv_rede_escolas>

=cut

__PACKAGE__->table("analytics.mv_rede_escolas");

=head1 ACCESSORS

=head2 co_municipio

Código IBGE do município (7 dígitos)

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
  "codigo_rede",
  { data_type => "integer", is_nullable => 1 },
  "rede",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "total_escolas",
  { data_type => "bigint", is_nullable => 1 },
  "total_etapas",
  { data_type => "bigint", is_nullable => 1 },
  "media_etapas",
  { data_type => "numeric", is_nullable => 1 },
  "total_matriculas",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_infantil",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_fundamental",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_fundamental_ai",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_fundamental_af",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_medio",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_profissional",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_eja",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_especial",
  { data_type => "bigint", is_nullable => 1 },
  "matriculas_integral",
  { data_type => "bigint", is_nullable => 1 },
  "total_docentes",
  { data_type => "bigint", is_nullable => 1 },
  "docentes_superior",
  { data_type => "bigint", is_nullable => 1 },
  "docentes_concursados",
  { data_type => "bigint", is_nullable => 1 },
  "ideb_fund_i",
  { data_type => "numeric", is_nullable => 1 },
  "ideb_fund_ii",
  { data_type => "numeric", is_nullable => 1 },
  "ideb_medio",
  { data_type => "numeric", is_nullable => 1 },
  "nota_media_fund_ii",
  { data_type => "numeric", is_nullable => 1 },
  "nota_matematica_fund_ii",
  { data_type => "numeric", is_nullable => 1 },
  "nota_portugues_fund_ii",
  { data_type => "numeric", is_nullable => 1 },
  "nota_media_medio",
  { data_type => "numeric", is_nullable => 1 },
  "ano_ideb",
  { data_type => "integer", is_nullable => 1 },
  "alunos_por_docente",
  { data_type => "numeric", is_nullable => 1 },
  "alunos_por_escola",
  { data_type => "numeric", is_nullable => 1 },
  "perc_docentes_superior",
  { data_type => "numeric", is_nullable => 1 },
  "perc_docentes_concursados",
  { data_type => "numeric", is_nullable => 1 },
);

=head1 UNIQUE CONSTRAINTS

=head2 C<idx_mv_rede_escolas_municipio_rede>

=over 4

=item * L</co_municipio>

=item * L</codigo_rede>

=back

=cut

__PACKAGE__->add_unique_constraint("idx_mv_rede_escolas_municipio_rede", ["co_municipio", "codigo_rede"]);

__PACKAGE__->belongs_to(
  'municipio',
  'EduMaps::Schema::Result::MunicipiosSp',
  { 'foreign.codigo_ibge' => 'self.co_municipio' },
  { join_type => 'INNER' },
);

1;