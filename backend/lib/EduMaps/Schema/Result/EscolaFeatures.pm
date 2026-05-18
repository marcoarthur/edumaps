use utf8;
package EduMaps::Schema::Result::EscolaFeatures;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::EscolaFeatures

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<analytics.escola_features>

=cut

__PACKAGE__->table("analytics.escola_features");

=head1 ACCESSORS

=head2 co_entidade

  data_type: 'text'
  is_nullable: 1

=head2 tp_localizacao

  data_type: 'integer'
  is_nullable: 1

=head2 tp_dependencia

  data_type: 'integer'
  is_nullable: 1

=head2 in_agua_potavel

  data_type: 'integer'
  is_nullable: 1

=head2 in_energia_rede_publica

  data_type: 'integer'
  is_nullable: 1

=head2 in_esgoto_rede_publica

  data_type: 'integer'
  is_nullable: 1

=head2 in_cozinha

  data_type: 'integer'
  is_nullable: 1

=head2 in_banheiro

  data_type: 'integer'
  is_nullable: 1

=head2 in_banheiro_pne

  data_type: 'integer'
  is_nullable: 1

=head2 in_refeitorio

  data_type: 'integer'
  is_nullable: 1

=head2 in_biblioteca

  data_type: 'integer'
  is_nullable: 1

=head2 in_laboratorio_ciencias

  data_type: 'integer'
  is_nullable: 1

=head2 in_laboratorio_informatica

  data_type: 'integer'
  is_nullable: 1

=head2 in_quadra_esportes

  data_type: 'integer'
  is_nullable: 1

=head2 in_patio_coberto

  data_type: 'integer'
  is_nullable: 1

=head2 in_parque_infantil

  data_type: 'integer'
  is_nullable: 1

=head2 in_computador

  data_type: 'integer'
  is_nullable: 1

=head2 in_internet

  data_type: 'integer'
  is_nullable: 1

=head2 in_banda_larga

  data_type: 'integer'
  is_nullable: 1

=head2 in_equip_multimidia

  data_type: 'integer'
  is_nullable: 1

=head2 in_equip_lousa_digital

  data_type: 'integer'
  is_nullable: 1

=head2 in_desktop_aluno

  data_type: 'integer'
  is_nullable: 1

=head2 in_tablet_aluno

  data_type: 'integer'
  is_nullable: 1

=head2 in_acessibilidade_rampas

  data_type: 'integer'
  is_nullable: 1

=head2 in_acessibilidade_corrimao

  data_type: 'integer'
  is_nullable: 1

=head2 in_acessibilidade_elevador

  data_type: 'integer'
  is_nullable: 1

=head2 in_acessibilidade_pisos_tateis

  data_type: 'integer'
  is_nullable: 1

=head2 in_acessibilidade_sinal_sonoro

  data_type: 'integer'
  is_nullable: 1

=head2 qt_salas_utilizadas

  data_type: 'integer'
  is_nullable: 1

=head2 qt_prof_administrativos

  data_type: 'integer'
  is_nullable: 1

=head2 qt_prof_servicos_gerais

  data_type: 'integer'
  is_nullable: 1

=head2 qt_prof_seguranca

  data_type: 'integer'
  is_nullable: 1

=head2 qt_desktop_aluno

  data_type: 'integer'
  is_nullable: 1

=head2 qt_comp_portatil_aluno

  data_type: 'integer'
  is_nullable: 1

=head2 qt_tablet_aluno

  data_type: 'integer'
  is_nullable: 1

=head2 qt_mat_bas

  data_type: 'integer'
  is_nullable: 1

=head2 qt_mat_inf

  data_type: 'integer'
  is_nullable: 1

=head2 qt_mat_fund

  data_type: 'integer'
  is_nullable: 1

=head2 qt_mat_med

  data_type: 'integer'
  is_nullable: 1

=head2 qt_mat_bas_int

  data_type: 'integer'
  is_nullable: 1

=head2 qt_doc_bas

  data_type: 'integer'
  is_nullable: 1

=head2 qt_doc_bas_fem

  data_type: 'integer'
  is_nullable: 1

=head2 qt_doc_bas_esco_sup_grad

  data_type: 'integer'
  is_nullable: 1

=head2 qt_doc_bas_esco_sup_pos_espec

  data_type: 'integer'
  is_nullable: 1

=head2 qt_doc_bas_vinculo_concur

  data_type: 'integer'
  is_nullable: 1

=head2 qt_gest_bas_esco_sup_grad

  data_type: 'integer'
  is_nullable: 1

=head2 qt_gest_bas_esco_sup_pos_espec

  data_type: 'integer'
  is_nullable: 1

=head2 qt_gest_bas_acesso_cargo_eleic

  data_type: 'integer'
  is_nullable: 1

=head2 qt_gest_bas_acesso_cargo_conca

  data_type: 'integer'
  is_nullable: 1

=head2 nota_media

  data_type: 'numeric'
  is_nullable: 1

=head2 etapa

  data_type: 'text'
  is_nullable: 1
  original: {data_type => "varchar"}

=head2 media_inse

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_1

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_2

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_3

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_4

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_5

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_6

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_7

  data_type: 'numeric'
  is_nullable: 1

=head2 pc_nivel_8

  data_type: 'numeric'
  is_nullable: 1

=head2 infra_essencial_score

  data_type: 'bigint'
  is_nullable: 1

=head2 espacos_pedagogicos_score

  data_type: 'bigint'
  is_nullable: 1

=head2 tecnologia_score

  data_type: 'bigint'
  is_nullable: 1

=head2 acessibilidade_score

  data_type: 'bigint'
  is_nullable: 1

=head2 salas_por_aluno

  data_type: 'numeric'
  is_nullable: 1

=head2 equipamentos_por_aluno

  data_type: 'numeric'
  is_nullable: 1

=head2 funcionarios_nd_por_aluno

  data_type: 'numeric'
  is_nullable: 1

=head2 docentes_por_aluno

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_docentes_superior

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_docentes_pos

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_docentes_concursados

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_docentes_feminino

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_mat_infantil

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_mat_fund

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_mat_medio

  data_type: 'numeric'
  is_nullable: 1

=head2 prop_mat_integral

  data_type: 'numeric'
  is_nullable: 1

=head2 alunos_por_sala

  data_type: 'numeric'
  is_nullable: 1

=head2 gestor_superior

  data_type: 'integer'
  is_nullable: 1

=head2 gestor_pos

  data_type: 'integer'
  is_nullable: 1

=head2 gestor_acesso_democratico

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "text", is_nullable => 1 },
  "tp_localizacao",
  { data_type => "integer", is_nullable => 1 },
  "tp_dependencia",
  { data_type => "integer", is_nullable => 1 },
  "in_agua_potavel",
  { data_type => "integer", is_nullable => 1 },
  "in_energia_rede_publica",
  { data_type => "integer", is_nullable => 1 },
  "in_esgoto_rede_publica",
  { data_type => "integer", is_nullable => 1 },
  "in_cozinha",
  { data_type => "integer", is_nullable => 1 },
  "in_banheiro",
  { data_type => "integer", is_nullable => 1 },
  "in_banheiro_pne",
  { data_type => "integer", is_nullable => 1 },
  "in_refeitorio",
  { data_type => "integer", is_nullable => 1 },
  "in_biblioteca",
  { data_type => "integer", is_nullable => 1 },
  "in_laboratorio_ciencias",
  { data_type => "integer", is_nullable => 1 },
  "in_laboratorio_informatica",
  { data_type => "integer", is_nullable => 1 },
  "in_quadra_esportes",
  { data_type => "integer", is_nullable => 1 },
  "in_patio_coberto",
  { data_type => "integer", is_nullable => 1 },
  "in_parque_infantil",
  { data_type => "integer", is_nullable => 1 },
  "in_computador",
  { data_type => "integer", is_nullable => 1 },
  "in_internet",
  { data_type => "integer", is_nullable => 1 },
  "in_banda_larga",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_multimidia",
  { data_type => "integer", is_nullable => 1 },
  "in_equip_lousa_digital",
  { data_type => "integer", is_nullable => 1 },
  "in_desktop_aluno",
  { data_type => "integer", is_nullable => 1 },
  "in_tablet_aluno",
  { data_type => "integer", is_nullable => 1 },
  "in_acessibilidade_rampas",
  { data_type => "integer", is_nullable => 1 },
  "in_acessibilidade_corrimao",
  { data_type => "integer", is_nullable => 1 },
  "in_acessibilidade_elevador",
  { data_type => "integer", is_nullable => 1 },
  "in_acessibilidade_pisos_tateis",
  { data_type => "integer", is_nullable => 1 },
  "in_acessibilidade_sinal_sonoro",
  { data_type => "integer", is_nullable => 1 },
  "qt_salas_utilizadas",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_administrativos",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_servicos_gerais",
  { data_type => "integer", is_nullable => 1 },
  "qt_prof_seguranca",
  { data_type => "integer", is_nullable => 1 },
  "qt_desktop_aluno",
  { data_type => "integer", is_nullable => 1 },
  "qt_comp_portatil_aluno",
  { data_type => "integer", is_nullable => 1 },
  "qt_tablet_aluno",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_inf",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_fund",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_med",
  { data_type => "integer", is_nullable => 1 },
  "qt_mat_bas_int",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_fem",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_grad",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_esco_sup_pos_espec",
  { data_type => "integer", is_nullable => 1 },
  "qt_doc_bas_vinculo_concur",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_grad",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_esco_sup_pos_espec",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_eleic",
  { data_type => "integer", is_nullable => 1 },
  "qt_gest_bas_acesso_cargo_conca",
  { data_type => "integer", is_nullable => 1 },
  "nota_media",
  { data_type => "numeric", is_nullable => 1 },
  "etapa",
  {
    data_type   => "text",
    is_nullable => 1,
    original    => { data_type => "varchar" },
  },
  "media_inse",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_1",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_2",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_3",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_4",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_5",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_6",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_7",
  { data_type => "numeric", is_nullable => 1 },
  "pc_nivel_8",
  { data_type => "numeric", is_nullable => 1 },
  "infra_essencial_score",
  { data_type => "bigint", is_nullable => 1 },
  "espacos_pedagogicos_score",
  { data_type => "bigint", is_nullable => 1 },
  "tecnologia_score",
  { data_type => "bigint", is_nullable => 1 },
  "acessibilidade_score",
  { data_type => "bigint", is_nullable => 1 },
  "salas_por_aluno",
  { data_type => "numeric", is_nullable => 1 },
  "equipamentos_por_aluno",
  { data_type => "numeric", is_nullable => 1 },
  "funcionarios_nd_por_aluno",
  { data_type => "numeric", is_nullable => 1 },
  "docentes_por_aluno",
  { data_type => "numeric", is_nullable => 1 },
  "prop_docentes_superior",
  { data_type => "numeric", is_nullable => 1 },
  "prop_docentes_pos",
  { data_type => "numeric", is_nullable => 1 },
  "prop_docentes_concursados",
  { data_type => "numeric", is_nullable => 1 },
  "prop_docentes_feminino",
  { data_type => "numeric", is_nullable => 1 },
  "prop_mat_infantil",
  { data_type => "numeric", is_nullable => 1 },
  "prop_mat_fund",
  { data_type => "numeric", is_nullable => 1 },
  "prop_mat_medio",
  { data_type => "numeric", is_nullable => 1 },
  "prop_mat_integral",
  { data_type => "numeric", is_nullable => 1 },
  "alunos_por_sala",
  { data_type => "numeric", is_nullable => 1 },
  "gestor_superior",
  { data_type => "integer", is_nullable => 1 },
  "gestor_pos",
  { data_type => "integer", is_nullable => 1 },
  "gestor_acesso_democratico",
  { data_type => "integer", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-18 15:25:32
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SyJ3GTODnRhshrsRUrvlCw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
