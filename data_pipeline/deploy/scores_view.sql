-- Deploy edumaps:scores_view to pg

BEGIN;

  CREATE OR REPLACE VIEW clean.censo_escolas_scores AS
  SELECT
      ce.co_entidade,

      -- 1. Score de Infraestrutura Essencial (0-10)
      ROUND(
          (
            COALESCE(ce.in_agua_potavel, 0) +
            COALESCE(ce.in_agua_rede_publica, 0) +
            GREATEST(
              COALESCE(ce.in_esgoto_rede_publica, 0),
              COALESCE(ce.in_esgoto_fossa_septica, 0)
            ) +
            COALESCE(ce.in_energia_rede_publica, 0) +
            COALESCE(ce.in_lixo_servico_coleta, 0)
          ) / 5.0 * 10,
          1
      ) AS score_infra_essencial,

      -- 2. Score de Tecnologia e Conectividade (existente)
      ROUND(
          (
            COALESCE(ce.in_computador, 0) +
            COALESCE(ce.in_internet, 0) +
            COALESCE(ce.in_banda_larga, 0) +
            COALESCE(ce.in_laboratorio_informatica, 0) +
            COALESCE(ce.in_equip_lousa_digital, 0) +
            COALESCE(ce.in_equip_multimidia, 0)
          ) / 6.0 * 10,
          1
      ) AS score_tecnologia,

      -- 3. Score de Espaços e Instalações
      ROUND(
          (
            COALESCE(ce.in_biblioteca, 0) +
            COALESCE(ce.in_laboratorio_ciencias, 0) +
            COALESCE(ce.in_quadra_esportes, 0) +
            COALESCE(ce.in_patio_coberto, 0) +
            COALESCE(ce.in_cozinha, 0) +
            COALESCE(ce.in_refeitorio, 0) +
            COALESCE(ce.in_auditorio, 0) +
            COALESCE(ce.in_parque_infantil, 0)
          ) / 8.0 * 10,
          1
      ) AS score_espacos,

      -- 4. Score de Acessibilidade (existente)
      ROUND(
          (
            COALESCE(ce.in_banheiro_pne, 0) +
            COALESCE(ce.in_acessibilidade_rampas, 0) +
            COALESCE(ce.in_acessibilidade_corrimao, 0) +
            COALESCE(ce.in_acessibilidade_sinalizacao, 0) +
            COALESCE(ce.in_acessibilidade_vao_livre, 0) +
            COALESCE(ce.in_acessibilidade_pisos_tateis, 0) +
            COALESCE(ce.in_sala_atendimento_especial, 0)
          ) / 7.0 * 10,
          1
      ) AS score_acessibilidade,

      -- 5. Score de Apoio Multidisciplinar (existente)
      ROUND(
          (
            CASE WHEN COALESCE(ce.qt_prof_psicologo, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_fonaudiologo, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_nutricionista, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_assist_social, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_trad_libras, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_bibliotecario, 0) > 0 THEN 1 ELSE 0 END +
            CASE WHEN COALESCE(ce.qt_prof_seguranca, 0) > 0 THEN 1 ELSE 0 END
          ) / 7.0 * 10,
          1
      ) AS score_apoio_multidisciplinar,

      -- 6. Score de Material Pedagógico
      ROUND(
          (
            COALESCE(ce.in_material_ped_multimidia, 0) +
            COALESCE(ce.in_material_ped_infantil, 0) +
            COALESCE(ce.in_material_ped_cientifico, 0) +
            COALESCE(ce.in_material_ped_jogos, 0) +
            COALESCE(ce.in_material_ped_artisticas, 0) +
            COALESCE(ce.in_material_ped_desportiva, 0) +
            COALESCE(ce.in_material_ped_edu_esp, 0)
          ) / 7.0 * 10,
          1
      ) AS score_material_pedagogico,

      -- 7. Score de Diversidade de Oferta
      ROUND(
          (
            COALESCE(ce.in_comum_creche, 0) +
            COALESCE(ce.in_comum_pre, 0) +
            COALESCE(ce.in_comum_fund_ai, 0) +
            COALESCE(ce.in_comum_fund_af, 0) +
            COALESCE(ce.in_comum_medio_medio, 0) +
            COALESCE(ce.in_comum_eja_fund, 0) +
            COALESCE(ce.in_comum_eja_medio, 0) +
            COALESCE(ce.in_profissionalizante, 0)
          ) / 8.0 * 10,
          1
      ) AS score_diversidade_oferta,

      -- 8. Score de Gestão e Participação
      ROUND(
          (
            COALESCE(ce.in_orgao_conselho_escolar, 0) +
            COALESCE(ce.in_orgao_ass_pais, 0) +
            COALESCE(ce.in_orgao_gremio_estudantil, 0) +
            COALESCE(ce.in_redes_sociais, 0)
          ) / 4.0 * 10,
          1
      ) AS score_gestao_participacao,

      -----------------------------------------------------------------
      -- SCORES CUSTOMIZADOS DE VOCÊS (normalizados 0-10)
      -----------------------------------------------------------------

      -- 9. Internet Score (ponderado)
      ROUND(
          (
            3 * CASE WHEN ce.in_internet = 1 THEN 1 ELSE 0 END +
            3 * CASE WHEN ce.in_banda_larga = 1 THEN 1 ELSE 0 END +
            1 * CASE WHEN ce.in_equip_lousa_digital = 1 THEN 1 ELSE 0 END +
            3 * CASE WHEN ce.in_laboratorio_informatica = 1 THEN 1 ELSE 0 END +
            2 * CASE WHEN ce.in_internet_aprendizagem = 1 THEN 1 ELSE 0 END +
            1 * CASE WHEN ce.in_acesso_internet_computador = 1 THEN 1 ELSE 0 END +
            1 * CASE WHEN ce.in_aces_internet_disp_pessoais = 1 THEN 1 ELSE 0 END +
            2 * CASE WHEN ce.in_internet_comunidade = 1 THEN 1 ELSE 0 END
          ) / 16.0 * 10,
          1
      ) AS score_internet_custom,

      -- 10. Accessibility Score (ponderado)
      ROUND(
          (
            3 * CASE WHEN ce.in_acessibilidade_rampas = 1 THEN 1 ELSE 0 END +
            2 * CASE WHEN ce.in_acessibilidade_elevador = 1 THEN 1 ELSE 0 END +
            3 * CASE WHEN ce.in_banheiro_pne = 1 THEN 1 ELSE 0 END +
            1 * CASE WHEN ce.in_acessibilidade_sinal_sonoro = 1 THEN 1 ELSE 0 END +
            2 * CASE WHEN ce.in_acessibilidade_pisos_tateis = 1 THEN 1 ELSE 0 END
          ) / 11.0 * 10,
          1
      ) AS score_acessibilidade_custom,

      -- 11. Support Staff Score (ponderado)
      ROUND(
          (
            CASE WHEN ce.qt_prof_psicologo > 0 THEN 3 ELSE 0 END +
            CASE WHEN ce.qt_prof_nutricionista > 0 THEN 2 ELSE 0 END +
            CASE WHEN ce.qt_prof_bibliotecario > 0 THEN 2 ELSE 0 END +
            CASE WHEN ce.qt_prof_coordenador > 1 THEN 1 ELSE 0 END +
            CASE WHEN ce.qt_prof_assist_social > 0 THEN 3 ELSE 0 END
          ) / 11.0 * 10,
          1
      ) AS score_support_staff_custom

  FROM clean.censo_escolas ce;

COMMIT;
