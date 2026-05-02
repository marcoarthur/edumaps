use utf8;
package EduMaps::Schema::Result::CensoEscolasScores;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

EduMaps::Schema::Result::CensoEscolasScores

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->table_class("DBIx::Class::ResultSource::View");

=head1 TABLE: C<clean.censo_escolas_scores>

=cut

__PACKAGE__->table("clean.censo_escolas_scores");
__PACKAGE__->result_source_instance->view_definition(" SELECT co_entidade,\n    round((((((((COALESCE((in_agua_potavel)::integer, 0) + COALESCE((in_agua_rede_publica)::integer, 0)) + GREATEST(COALESCE((in_esgoto_rede_publica)::integer, 0), COALESCE((in_esgoto_fossa_septica)::integer, 0))) + COALESCE((in_energia_rede_publica)::integer, 0)) + COALESCE((in_lixo_servico_coleta)::integer, 0)))::numeric / 5.0) * (10)::numeric), 1) AS score_infra_essencial,\n    round(((((((((COALESCE((in_computador)::integer, 0) + COALESCE((in_internet)::integer, 0)) + COALESCE((in_banda_larga)::integer, 0)) + COALESCE((in_laboratorio_informatica)::integer, 0)) + COALESCE((in_equip_lousa_digital)::integer, 0)) + COALESCE((in_equip_multimidia)::integer, 0)))::numeric / 6.0) * (10)::numeric), 1) AS score_tecnologia,\n    round(((((((((((COALESCE((in_biblioteca)::integer, 0) + COALESCE((in_laboratorio_ciencias)::integer, 0)) + COALESCE((in_quadra_esportes)::integer, 0)) + COALESCE((in_patio_coberto)::integer, 0)) + COALESCE((in_cozinha)::integer, 0)) + COALESCE((in_refeitorio)::integer, 0)) + COALESCE((in_auditorio)::integer, 0)) + COALESCE((in_parque_infantil)::integer, 0)))::numeric / 8.0) * (10)::numeric), 1) AS score_espacos,\n    round((((((((((COALESCE((in_banheiro_pne)::integer, 0) + COALESCE((in_acessibilidade_rampas)::integer, 0)) + COALESCE((in_acessibilidade_corrimao)::integer, 0)) + COALESCE((in_acessibilidade_sinalizacao)::integer, 0)) + COALESCE((in_acessibilidade_vao_livre)::integer, 0)) + COALESCE((in_acessibilidade_pisos_tateis)::integer, 0)) + COALESCE((in_sala_atendimento_especial)::integer, 0)))::numeric / 7.0) * (10)::numeric), 1) AS score_acessibilidade,\n    round((((((((((\n        CASE\n            WHEN (COALESCE(qt_prof_psicologo, 0) > 0) THEN 1\n            ELSE 0\n        END +\n        CASE\n            WHEN (COALESCE(qt_prof_fonaudiologo, 0) > 0) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (COALESCE(qt_prof_nutricionista, 0) > 0) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (COALESCE(qt_prof_assist_social, 0) > 0) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (COALESCE(qt_prof_trad_libras, 0) > 0) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (COALESCE(qt_prof_bibliotecario, 0) > 0) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (COALESCE(qt_prof_seguranca, 0) > 0) THEN 1\n            ELSE 0\n        END))::numeric / 7.0) * (10)::numeric), 1) AS score_apoio_multidisciplinar,\n    round((((((((((COALESCE((in_material_ped_multimidia)::integer, 0) + COALESCE((in_material_ped_infantil)::integer, 0)) + COALESCE((in_material_ped_cientifico)::integer, 0)) + COALESCE((in_material_ped_jogos)::integer, 0)) + COALESCE((in_material_ped_artisticas)::integer, 0)) + COALESCE((in_material_ped_desportiva)::integer, 0)) + COALESCE((in_material_ped_edu_esp)::integer, 0)))::numeric / 7.0) * (10)::numeric), 1) AS score_material_pedagogico,\n    round(((((((((((COALESCE((in_comum_creche)::integer, 0) + COALESCE((in_comum_pre)::integer, 0)) + COALESCE((in_comum_fund_ai)::integer, 0)) + COALESCE((in_comum_fund_af)::integer, 0)) + COALESCE((in_comum_medio_medio)::integer, 0)) + COALESCE((in_comum_eja_fund)::integer, 0)) + COALESCE((in_comum_eja_medio)::integer, 0)) + COALESCE((in_profissionalizante)::integer, 0)))::numeric / 8.0) * (10)::numeric), 1) AS score_diversidade_oferta,\n    round(((((((COALESCE((in_orgao_conselho_escolar)::integer, 0) + COALESCE((in_orgao_ass_pais)::integer, 0)) + COALESCE((in_orgao_gremio_estudantil)::integer, 0)) + COALESCE((in_redes_sociais)::integer, 0)))::numeric / 4.0) * (10)::numeric), 1) AS score_gestao_participacao,\n    round((((((((((((3 *\n        CASE\n            WHEN (in_internet = 1) THEN 1\n            ELSE 0\n        END) + (3 *\n        CASE\n            WHEN (in_banda_larga = 1) THEN 1\n            ELSE 0\n        END)) + (1 *\n        CASE\n            WHEN (in_equip_lousa_digital = 1) THEN 1\n            ELSE 0\n        END)) + (3 *\n        CASE\n            WHEN (in_laboratorio_informatica = 1) THEN 1\n            ELSE 0\n        END)) + (2 *\n        CASE\n            WHEN (in_internet_aprendizagem = 1) THEN 1\n            ELSE 0\n        END)) + (1 *\n        CASE\n            WHEN (in_acesso_internet_computador = 1) THEN 1\n            ELSE 0\n        END)) + (1 *\n        CASE\n            WHEN (in_aces_internet_disp_pessoais = 1) THEN 1\n            ELSE 0\n        END)) + (2 *\n        CASE\n            WHEN (in_internet_comunidade = 1) THEN 1\n            ELSE 0\n        END)))::numeric / 16.0) * (10)::numeric), 1) AS score_internet_custom,\n    round(((((((((3 *\n        CASE\n            WHEN (in_acessibilidade_rampas = 1) THEN 1\n            ELSE 0\n        END) + (2 *\n        CASE\n            WHEN (in_acessibilidade_elevador = 1) THEN 1\n            ELSE 0\n        END)) + (3 *\n        CASE\n            WHEN (in_banheiro_pne = 1) THEN 1\n            ELSE 0\n        END)) + (1 *\n        CASE\n            WHEN (in_acessibilidade_sinal_sonoro = 1) THEN 1\n            ELSE 0\n        END)) + (2 *\n        CASE\n            WHEN (in_acessibilidade_pisos_tateis = 1) THEN 1\n            ELSE 0\n        END)))::numeric / 11.0) * (10)::numeric), 1) AS score_acessibilidade_custom,\n    round((((((((\n        CASE\n            WHEN (qt_prof_psicologo > 0) THEN 3\n            ELSE 0\n        END +\n        CASE\n            WHEN (qt_prof_nutricionista > 0) THEN 2\n            ELSE 0\n        END) +\n        CASE\n            WHEN (qt_prof_bibliotecario > 0) THEN 2\n            ELSE 0\n        END) +\n        CASE\n            WHEN (qt_prof_coordenador > 1) THEN 1\n            ELSE 0\n        END) +\n        CASE\n            WHEN (qt_prof_assist_social > 0) THEN 3\n            ELSE 0\n        END))::numeric / 11.0) * (10)::numeric), 1) AS score_support_staff_custom\n   FROM censo_escolas ce");

=head1 ACCESSORS

=head2 co_entidade

  data_type: 'bigint'
  is_nullable: 1

=head2 score_infra_essencial

  data_type: 'numeric'
  is_nullable: 1

=head2 score_tecnologia

  data_type: 'numeric'
  is_nullable: 1

=head2 score_espacos

  data_type: 'numeric'
  is_nullable: 1

=head2 score_acessibilidade

  data_type: 'numeric'
  is_nullable: 1

=head2 score_apoio_multidisciplinar

  data_type: 'numeric'
  is_nullable: 1

=head2 score_material_pedagogico

  data_type: 'numeric'
  is_nullable: 1

=head2 score_diversidade_oferta

  data_type: 'numeric'
  is_nullable: 1

=head2 score_gestao_participacao

  data_type: 'numeric'
  is_nullable: 1

=head2 score_internet_custom

  data_type: 'numeric'
  is_nullable: 1

=head2 score_acessibilidade_custom

  data_type: 'numeric'
  is_nullable: 1

=head2 score_support_staff_custom

  data_type: 'numeric'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "co_entidade",
  { data_type => "bigint", is_nullable => 1 },
  "score_infra_essencial",
  { data_type => "numeric", is_nullable => 1 },
  "score_tecnologia",
  { data_type => "numeric", is_nullable => 1 },
  "score_espacos",
  { data_type => "numeric", is_nullable => 1 },
  "score_acessibilidade",
  { data_type => "numeric", is_nullable => 1 },
  "score_apoio_multidisciplinar",
  { data_type => "numeric", is_nullable => 1 },
  "score_material_pedagogico",
  { data_type => "numeric", is_nullable => 1 },
  "score_diversidade_oferta",
  { data_type => "numeric", is_nullable => 1 },
  "score_gestao_participacao",
  { data_type => "numeric", is_nullable => 1 },
  "score_internet_custom",
  { data_type => "numeric", is_nullable => 1 },
  "score_acessibilidade_custom",
  { data_type => "numeric", is_nullable => 1 },
  "score_support_staff_custom",
  { data_type => "numeric", is_nullable => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07053 @ 2026-05-01 13:47:46
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:q4JqbCvE0SuNxLeIYEfbGQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration

__PACKAGE__->belongs_to(
  'escola',
  'EduMaps::Schema::Result::CensoEscolas',
  { 'foreign.co_entidade' => 'self.co_entidade' },
);
1;
