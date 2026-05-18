-- Deploy edumaps:analytic_school_model to pg

BEGIN;
  CREATE OR REPLACE FUNCTION analytics.prepare_school_data(
    p_censo_year INTEGER,
    p_ideb_year INTEGER,
    p_inse_year INTEGER,
    p_etapa TEXT
  )
  RETURNS TABLE (
    co_entidade TEXT,
    tp_localizacao INTEGER,
    tp_dependencia INTEGER,
    in_agua_potavel INTEGER,
    in_energia_rede_publica INTEGER,
    in_esgoto_rede_publica INTEGER,
    in_cozinha INTEGER,
    in_banheiro INTEGER,
    in_banheiro_pne INTEGER,
    in_refeitorio INTEGER,
    in_biblioteca INTEGER,
    in_laboratorio_ciencias INTEGER,
    in_laboratorio_informatica INTEGER,
    in_quadra_esportes INTEGER,
    in_patio_coberto INTEGER,
    in_parque_infantil INTEGER,
    in_computador INTEGER,
    in_internet INTEGER,
    in_banda_larga INTEGER,
    in_equip_multimidia INTEGER,
    in_equip_lousa_digital INTEGER,
    in_desktop_aluno INTEGER,
    in_tablet_aluno INTEGER,
    in_acessibilidade_rampas INTEGER,
    in_acessibilidade_corrimao INTEGER,
    in_acessibilidade_elevador INTEGER,
    in_acessibilidade_pisos_tateis INTEGER,
    in_acessibilidade_sinal_sonoro INTEGER,
    qt_salas_utilizadas INTEGER,
    qt_prof_administrativos INTEGER,
    qt_prof_servicos_gerais INTEGER,
    qt_prof_seguranca INTEGER,
    qt_desktop_aluno INTEGER,
    qt_comp_portatil_aluno INTEGER,
    qt_tablet_aluno INTEGER,
    qt_mat_bas INTEGER,
    qt_mat_inf INTEGER,
    qt_mat_fund INTEGER,
    qt_mat_med INTEGER,
    qt_mat_bas_int INTEGER,
    qt_doc_bas INTEGER,
    qt_doc_bas_fem INTEGER,
    qt_doc_bas_esco_sup_grad INTEGER,
    qt_doc_bas_esco_sup_pos_espec INTEGER,
    qt_doc_bas_vinculo_concur INTEGER,
    qt_gest_bas_esco_sup_grad INTEGER,
    qt_gest_bas_esco_sup_pos_espec INTEGER,
    qt_gest_bas_acesso_cargo_eleic INTEGER,
    qt_gest_bas_acesso_cargo_conca INTEGER,
    nota_media NUMERIC,
    etapa VARCHAR(15), 
    media_inse NUMERIC,
    pc_nivel_1 NUMERIC,
    pc_nivel_2 NUMERIC,
    pc_nivel_3 NUMERIC,
    pc_nivel_4 NUMERIC,
    pc_nivel_5 NUMERIC,
    pc_nivel_6 NUMERIC,
    pc_nivel_7 NUMERIC,
    pc_nivel_8 NUMERIC,
    infra_essencial_score BIGINT,
    espacos_pedagogicos_score BIGINT,
    tecnologia_score BIGINT,
    acessibilidade_score BIGINT,
    salas_por_aluno NUMERIC,
    equipamentos_por_aluno NUMERIC,
    funcionarios_nd_por_aluno NUMERIC,
    docentes_por_aluno NUMERIC,
    prop_docentes_superior NUMERIC,
    prop_docentes_pos NUMERIC,
    prop_docentes_concursados NUMERIC,
    prop_docentes_feminino NUMERIC,
    prop_mat_infantil NUMERIC,
    prop_mat_fund NUMERIC,
    prop_mat_medio NUMERIC,
    prop_mat_integral NUMERIC,
    alunos_por_sala NUMERIC,
    gestor_superior INTEGER,
    gestor_pos INTEGER,
    gestor_acesso_democratico INTEGER
  )
  LANGUAGE sql
  STABLE
  AS $$
    WITH
      -- Filtrar e selecionar as colunas necessárias de cada tabela
      escolas AS (
        SELECT
          co_entidade,
          tp_localizacao,
          tp_dependencia,
          in_agua_potavel,
          in_energia_rede_publica,
          in_esgoto_rede_publica,
          in_cozinha,
          in_banheiro,
          in_banheiro_pne,
          in_refeitorio,
          in_biblioteca,
          in_laboratorio_ciencias,
          in_laboratorio_informatica,
          in_quadra_esportes,
          in_patio_coberto,
          in_parque_infantil,
          in_computador,
          in_internet,
          in_banda_larga,
          in_equip_multimidia,
          in_equip_lousa_digital,
          in_desktop_aluno,
          in_tablet_aluno,
          in_acessibilidade_rampas,
          in_acessibilidade_corrimao,
          in_acessibilidade_elevador,
          in_acessibilidade_pisos_tateis,
          in_acessibilidade_sinal_sonoro,
          qt_salas_utilizadas,
          qt_prof_administrativos,
          qt_prof_servicos_gerais,
          qt_prof_seguranca,
          qt_desktop_aluno,
          qt_comp_portatil_aluno,
          qt_tablet_aluno
        FROM clean.censo_escolas
        WHERE nu_ano_censo = p_censo_year
      ),
      matriculas AS (
        SELECT
          co_entidade,
          qt_mat_bas,
          qt_mat_inf,
          qt_mat_fund,
          qt_mat_med,
          qt_mat_bas_int
        FROM clean.censo_matriculas
        WHERE nu_ano_censo = p_censo_year
      ),
      docentes AS (
        SELECT
          co_entidade,
          qt_doc_bas,
          qt_doc_bas_fem,
          qt_doc_bas_esco_sup_grad,
          qt_doc_bas_esco_sup_pos_espec,
          qt_doc_bas_vinculo_concur
        FROM clean.censo_docentes
        WHERE nu_ano_censo = p_censo_year
      ),
      gestor AS (
        SELECT
          co_entidade,
          qt_gest_bas_esco_sup_grad,
          qt_gest_bas_esco_sup_pos_espec,
          qt_gest_bas_acesso_cargo_eleic,
          qt_gest_bas_acesso_cargo_conca
        FROM clean.censo_gestor
        WHERE nu_ano_censo = p_censo_year
      ),
      ideb AS (
        SELECT DISTINCT
          id_escola AS co_entidade,
          nota_media, etapa
        FROM clean.ideb_notas_escolas
        WHERE ano = p_ideb_year AND etapa = p_etapa
      ),
      inse AS (
        SELECT
          id_escola AS co_entidade,
          media_inse,
          pc_nivel_1,
          pc_nivel_2,
          pc_nivel_3,
          pc_nivel_4,
          pc_nivel_5,
          pc_nivel_6,
          pc_nivel_7,
          pc_nivel_8
        FROM clean.inse
        WHERE nu_ano_saeb = p_inse_year
      ),
      joined AS (
        SELECT
          e.*,
          m.qt_mat_bas,
          m.qt_mat_inf,
          m.qt_mat_fund,
          m.qt_mat_med,
          m.qt_mat_bas_int,
          d.qt_doc_bas,
          d.qt_doc_bas_fem,
          d.qt_doc_bas_esco_sup_grad,
          d.qt_doc_bas_esco_sup_pos_espec,
          d.qt_doc_bas_vinculo_concur,
          g.qt_gest_bas_esco_sup_grad,
          g.qt_gest_bas_esco_sup_pos_espec,
          g.qt_gest_bas_acesso_cargo_eleic,
          g.qt_gest_bas_acesso_cargo_conca,
          i.nota_media,
          i.etapa,
          s.media_inse,
          s.pc_nivel_1,
          s.pc_nivel_2,
          s.pc_nivel_3,
          s.pc_nivel_4,
          s.pc_nivel_5,
          s.pc_nivel_6,
          s.pc_nivel_7,
          s.pc_nivel_8
        FROM clean.censo_escolas e
        LEFT JOIN matriculas m ON e.co_entidade = m.co_entidade
        LEFT JOIN docentes d ON e.co_entidade = d.co_entidade
        LEFT JOIN gestor g ON e.co_entidade = g.co_entidade
        LEFT JOIN ideb i ON e.co_entidade = i.co_entidade
        LEFT JOIN inse s ON e.co_entidade = s.co_entidade
        WHERE i.nota_media IS NOT NULL   -- remove escolas sem IDEB
      )
    SELECT
      co_entidade,
      tp_localizacao,
      tp_dependencia,
      in_agua_potavel,
      in_energia_rede_publica,
      in_esgoto_rede_publica,
      in_cozinha,
      in_banheiro,
      in_banheiro_pne,
      in_refeitorio,
      in_biblioteca,
      in_laboratorio_ciencias,
      in_laboratorio_informatica,
      in_quadra_esportes,
      in_patio_coberto,
      in_parque_infantil,
      in_computador,
      in_internet,
      in_banda_larga,
      in_equip_multimidia,
      in_equip_lousa_digital,
      in_desktop_aluno,
      in_tablet_aluno,
      in_acessibilidade_rampas,
      in_acessibilidade_corrimao,
      in_acessibilidade_elevador,
      in_acessibilidade_pisos_tateis,
      in_acessibilidade_sinal_sonoro,
      COALESCE(qt_salas_utilizadas, 0) AS qt_salas_utilizadas,
      COALESCE(qt_prof_administrativos, 0) AS qt_prof_administrativos,
      COALESCE(qt_prof_servicos_gerais, 0) AS qt_prof_servicos_gerais,
      COALESCE(qt_prof_seguranca, 0) AS qt_prof_seguranca,
      COALESCE(qt_desktop_aluno, 0) AS qt_desktop_aluno,
      COALESCE(qt_comp_portatil_aluno, 0) AS qt_comp_portatil_aluno,
      COALESCE(qt_tablet_aluno, 0) AS qt_tablet_aluno,
      COALESCE(qt_mat_bas, 0) AS qt_mat_bas,
      COALESCE(qt_mat_inf, 0) AS qt_mat_inf,
      COALESCE(qt_mat_fund, 0) AS qt_mat_fund,
      COALESCE(qt_mat_med, 0) AS qt_mat_med,
      COALESCE(qt_mat_bas_int, 0) AS qt_mat_bas_int,
      COALESCE(qt_doc_bas, 0) AS qt_doc_bas,
      COALESCE(qt_doc_bas_fem, 0) AS qt_doc_bas_fem,
      COALESCE(qt_doc_bas_esco_sup_grad, 0) AS qt_doc_bas_esco_sup_grad,
      COALESCE(qt_doc_bas_esco_sup_pos_espec, 0) AS qt_doc_bas_esco_sup_pos_espec,
      COALESCE(qt_doc_bas_vinculo_concur, 0) AS qt_doc_bas_vinculo_concur,
      COALESCE(qt_gest_bas_esco_sup_grad, 0) AS qt_gest_bas_esco_sup_grad,
      COALESCE(qt_gest_bas_esco_sup_pos_espec, 0) AS qt_gest_bas_esco_sup_pos_espec,
      COALESCE(qt_gest_bas_acesso_cargo_eleic, 0) AS qt_gest_bas_acesso_cargo_eleic,
      COALESCE(qt_gest_bas_acesso_cargo_conca, 0) AS qt_gest_bas_acesso_cargo_conca,
      nota_media,
      etapa,
      media_inse,
      COALESCE(pc_nivel_1,0.0) AS pc_nivel_1,
      COALESCE(pc_nivel_2,0.0) AS pc_nivel_2,
      COALESCE(pc_nivel_3,0.0) AS pc_nivel_3,
      COALESCE(pc_nivel_4,0.0) AS pc_nivel_4,
      COALESCE(pc_nivel_5,0.0) AS pc_nivel_5,
      COALESCE(pc_nivel_6,0.0) AS pc_nivel_6,
      COALESCE(pc_nivel_7,0.0) AS pc_nivel_7,
      COALESCE(pc_nivel_8,0.0) AS pc_nivel_8,
      -- Scores
      (COALESCE(in_agua_potavel,0) + COALESCE(in_energia_rede_publica,0) +
       COALESCE(in_esgoto_rede_publica,0) + COALESCE(in_cozinha,0) +
       COALESCE(in_banheiro,0) + COALESCE(in_banheiro_pne,0) +
       COALESCE(in_refeitorio,0)) AS infra_essencial_score,
      (COALESCE(in_biblioteca,0) + COALESCE(in_laboratorio_ciencias,0) +
       COALESCE(in_laboratorio_informatica,0) + COALESCE(in_quadra_esportes,0) +
       COALESCE(in_patio_coberto,0) + COALESCE(in_parque_infantil,0)) AS espacos_pedagogicos_score,
      (COALESCE(in_computador,0) + COALESCE(in_internet,0) +
       COALESCE(in_banda_larga,0) + COALESCE(in_equip_multimidia,0) +
       COALESCE(in_equip_lousa_digital,0) + COALESCE(in_desktop_aluno,0) +
       COALESCE(in_tablet_aluno,0)) AS tecnologia_score,
      (COALESCE(in_acessibilidade_rampas,0) + COALESCE(in_acessibilidade_corrimao,0) +
       COALESCE(in_acessibilidade_elevador,0) + COALESCE(in_acessibilidade_pisos_tateis,0) +
       COALESCE(in_acessibilidade_sinal_sonoro,0)) AS acessibilidade_score,
      -- Razões
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_salas_utilizadas,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS salas_por_aluno,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN (COALESCE(qt_desktop_aluno,0) + COALESCE(qt_comp_portatil_aluno,0) + COALESCE(qt_tablet_aluno,0))::NUMERIC / qt_mat_bas
           ELSE 0 END AS equipamentos_por_aluno,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN (COALESCE(qt_prof_administrativos,0) + COALESCE(qt_prof_servicos_gerais,0) + COALESCE(qt_prof_seguranca,0))::NUMERIC / qt_mat_bas
           ELSE 0 END AS funcionarios_nd_por_aluno,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_doc_bas,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS docentes_por_aluno,
      CASE WHEN COALESCE(qt_doc_bas,0) > 0
           THEN COALESCE(qt_doc_bas_esco_sup_grad,0)::NUMERIC / qt_doc_bas
           ELSE 0 END AS prop_docentes_superior,
      CASE WHEN COALESCE(qt_doc_bas,0) > 0
           THEN COALESCE(qt_doc_bas_esco_sup_pos_espec,0)::NUMERIC / qt_doc_bas
           ELSE 0 END AS prop_docentes_pos,
      CASE WHEN COALESCE(qt_doc_bas,0) > 0
           THEN COALESCE(qt_doc_bas_vinculo_concur,0)::NUMERIC / qt_doc_bas
           ELSE 0 END AS prop_docentes_concursados,
      CASE WHEN COALESCE(qt_doc_bas,0) > 0
           THEN COALESCE(qt_doc_bas_fem,0)::NUMERIC / qt_doc_bas
           ELSE 0 END AS prop_docentes_feminino,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_mat_inf,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS prop_mat_infantil,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_mat_fund,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS prop_mat_fund,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_mat_med,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS prop_mat_medio,
      CASE WHEN COALESCE(qt_mat_bas,0) > 0
           THEN COALESCE(qt_mat_bas_int,0)::NUMERIC / qt_mat_bas
           ELSE 0 END AS prop_mat_integral,
      CASE WHEN COALESCE(qt_salas_utilizadas,0) > 0
           THEN COALESCE(qt_mat_bas,0)::NUMERIC / qt_salas_utilizadas
           ELSE 0 END AS alunos_por_sala,
      -- Gestor flags
      CASE WHEN COALESCE(qt_gest_bas_esco_sup_grad,0) > 0 THEN 1 ELSE 0 END AS gestor_superior,
      CASE WHEN COALESCE(qt_gest_bas_esco_sup_pos_espec,0) > 0 THEN 1 ELSE 0 END AS gestor_pos,
      CASE WHEN (COALESCE(qt_gest_bas_acesso_cargo_eleic,0) > 0 OR
                 COALESCE(qt_gest_bas_acesso_cargo_conca,0) > 0) THEN 1 ELSE 0 END AS gestor_acesso_democratico
    FROM joined;
  $$;

  CREATE MATERIALIZED VIEW analytics.escola_features AS
  SELECT * FROM analytics.prepare_school_data(2025, 2023, 2023, 'fundamental_i')
  UNION ALL
  SELECT * FROM analytics.prepare_school_data(2025, 2023, 2023, 'fundamental_ii')
  UNION ALL
  SELECT * FROM analytics.prepare_school_data(2025, 2023, 2023, 'ensino_medio');

COMMIT;
