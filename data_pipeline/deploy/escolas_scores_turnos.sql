-- Deploy edumaps:escolas_scores_turnos to pg
-- requires: escolas_scores_cor_declarada
--
-- #473 (RS-01 da décima avaliação da P4): a parte "alunos por sala" (40%)
-- do score_capacidade_atendimento dividia todas as matrículas pelas salas
-- utilizadas. Escola de dois ou três turnos aparecia lotada: 16.220 escolas
-- com 0 na parte, 14.673 delas com menos de 35 alunos por sala em cada turno
-- (Censo 2025). Passa a ser por sala e por turno (matutino, vespertino e
-- noturno com matrícula, mínimo 1), com a mesma régua (0 com 50 ou mais).
-- Os outros scores e as outras partes não mudam.
--
-- Versão sobe para indices-v5 (COMMENT abaixo e $INDICES_VERSAO, #462).
-- A MV é apagada e recriada, com os índices, os comentários e o GRANT ao
-- edumaps_leitor. Nenhuma view do banco depende da MV.
--
-- Depois do deploy: bin/ranking.pl --source mv, SchoolEmbedding e o IVET
-- nacional (ivet-v1.7).

BEGIN;

  DROP MATERIALIZED VIEW clean.mv_escolas_scores;

  CREATE MATERIALIZED VIEW clean.mv_escolas_scores AS

  -- 1. Lista de todas as escolas ativas (base)
  WITH escolas_base AS (
      SELECT DISTINCT
          e.nu_ano_censo,
          e.co_entidade
      FROM clean.censo_escolas e
      WHERE e.tp_situacao_funcionamento = 1
  ),

  -- ========== 2. SCORE CAPACIDADE DE ATENDIMENTO ==========
  score_capacidade AS (
      SELECT
          e.nu_ano_censo,
          e.co_entidade,
          ROUND(
              0.4 * CASE
                  WHEN e.qt_salas_utilizadas > 0 AND COALESCE(m.qt_mat_bas, 0) > 0
                  -- #473: lotação por sala E POR TURNO. A escola de dois ou três
                  -- turnos põe várias turmas na mesma sala; dividir todas as
                  -- matrículas só pelas salas media os turnos, não a lotação.
                  -- Turnos = matutino, vespertino e noturno com matrícula (mín. 1).
                  THEN GREATEST(0, 10 * (1 - (m.qt_mat_bas::numeric / (e.qt_salas_utilizadas *
                         GREATEST(1, (COALESCE(m.qt_mat_bas_dm,0) > 0)::int + (COALESCE(m.qt_mat_bas_dv,0) > 0)::int
                                     + (COALESCE(m.qt_mat_bas_n,0) > 0)::int))) / 50))
                  ELSE 0
              END +
              0.2 * ( (COALESCE(e.in_comum_creche,0) + COALESCE(e.in_comum_pre,0) +
                        COALESCE(e.in_comum_fund_ai,0) + COALESCE(e.in_comum_fund_af,0) +
                        COALESCE(e.in_comum_medio_medio,0) + COALESCE(e.in_eja,0) +
                        COALESCE(e.in_profissionalizante,0) ) / 7.0 * 10 ) +
              0.2 * CASE
                  WHEN COALESCE(m.qt_mat_bas, 0) > 0
                  THEN (COALESCE(m.qt_mat_bas_int,0)::numeric / m.qt_mat_bas) * 10
                  ELSE 0
              END +
              0.2 * CASE WHEN e.in_alimentacao = 1 THEN 10 ELSE 0 END
          , 2) AS score_capacidade_atendimento
      FROM clean.censo_escolas e
      LEFT JOIN clean.censo_matriculas m
          ON e.co_entidade = m.co_entidade AND e.nu_ano_censo = m.nu_ano_censo
      WHERE e.tp_situacao_funcionamento = 1
        AND m.qt_mat_bas > 0          -- #467: sem matrícula, sem o índice
  ),

  -- ========== 3. SCORE INFRAESTRUTURA ==========
  score_infra AS (
      SELECT
          nu_ano_censo,
          co_entidade,
          ROUND(
              ( -- Categoria A
                  (COALESCE(in_agua_potavel,0) +
                   COALESCE(in_energia_rede_publica,0) +
                   CASE WHEN COALESCE(in_esgoto_rede_publica,0)=1 OR COALESCE(in_esgoto_fossa_septica,0)=1 THEN 1 ELSE 0 END +
                   COALESCE(in_lixo_servico_coleta,0) +
                   COALESCE(in_banheiro,0)
                  ) / 5.0 * 10
                + -- Categoria B
                  ( (CASE WHEN COALESCE(in_biblioteca,0)=1 OR COALESCE(in_biblioteca_sala_leitura,0)=1 THEN 1 ELSE 0 END) +
                    COALESCE(in_laboratorio_ciencias,0) +
                    COALESCE(in_laboratorio_informatica,0) +
                    COALESCE(in_quadra_esportes,0) +
                    COALESCE(in_cozinha,0) +
                    COALESCE(in_refeitorio,0) +
                    COALESCE(in_sala_diretoria,0) +
                    COALESCE(in_secretaria,0) +
                    COALESCE(in_sala_professor,0)
                  ) / 9.0 * 10
                + -- Categoria C
                  ( COALESCE(in_acessibilidade_rampas,0) +
                    COALESCE(in_acessibilidade_corrimao,0) +
                    COALESCE(in_acessibilidade_pisos_tateis,0) +
                    COALESCE(in_acessibilidade_sinalizacao,0) +
                    COALESCE(in_banheiro_pne,0)
                  ) / 5.0 * 10
                + -- Categoria D
                  ( COALESCE(in_computador,0) +
                    COALESCE(in_internet,0) +
                    COALESCE(in_equip_lousa_digital,0) +
                    COALESCE(in_equip_multimidia,0) +
                    CASE WHEN COALESCE(in_equip_impressora,0)=1 OR COALESCE(in_equip_impressora_mult,0)=1 THEN 1 ELSE 0 END
                  ) / 5.0 * 10
              ) / 4.0
          , 2) AS score_infraestrutura
      FROM clean.censo_escolas
      WHERE tp_situacao_funcionamento = 1
  ),

  -- ========== 4. SCORE CAPACITAÇÃO DOCENTE ==========
  score_docente AS (
    SELECT
    d.nu_ano_censo,
    d.co_entidade,
    ROUND(
      0.3 * LEAST(1, COALESCE(d.qt_doc_bas_esco_sup_grad,0)::numeric / NULLIF(d.qt_doc_bas,0)) * 10 +
      0.3 * LEAST(1, (COALESCE(d.qt_doc_bas_esco_sup_pos_espec,0) +
          COALESCE(d.qt_doc_bas_esco_sup_pos_mestra,0) +
          COALESCE(d.qt_doc_bas_esco_sup_pos_douto,0))::numeric / NULLIF(d.qt_doc_bas,0)) * 10 +
      0.2 * LEAST(1, COALESCE(d.qt_doc_bas_vinculo_concur,0)::numeric / NULLIF(d.qt_doc_bas,0)) * 10 +
      0.2 * LEAST(1, (COALESCE(d.qt_doc_bas_espec_cre,0) +
          COALESCE(d.qt_doc_bas_espec_pre_escola,0) +
          COALESCE(d.qt_doc_bas_espec_anos_iniciais,0) +
          COALESCE(d.qt_doc_bas_espec_anos_finais,0) +
          COALESCE(d.qt_doc_bas_espec_ens_medio,0) +
          COALESCE(d.qt_doc_bas_espec_eja,0) +
          COALESCE(d.qt_doc_bas_espec_ed_especial,0) +
          COALESCE(d.qt_doc_bas_espec_bil_surdos,0) +
          COALESCE(d.qt_doc_bas_espec_ed_indigena,0) +
          COALESCE(d.qt_doc_bas_espec_campo,0) +
          COALESCE(d.qt_doc_bas_espec_ambiental,0) +
          COALESCE(d.qt_doc_bas_espec_dir_humanos,0) +
          COALESCE(d.qt_doc_bas_espec_div_sexual,0) +
          COALESCE(d.qt_doc_bas_espec_dir_adolesc,0) +
          COALESCE(d.qt_doc_bas_espec_afro,0) +
          COALESCE(d.qt_doc_bas_espec_gestao,0) +
          COALESCE(d.qt_doc_bas_espec_educ_tic,0) +
          COALESCE(d.qt_doc_bas_espec_outros,0))::numeric / NULLIF(d.qt_doc_bas,0)) * 10
      , 2) AS score_capacitacao_docente
    FROM clean.censo_docentes d
    WHERE d.qt_doc_bas > 0              -- #467: sem docente, sem o índice
  ),

  -- ========== 5. SCORE DIVERSIDADE DISCENTE ==========
  score_diversidade AS (
      -- #471: a parte racial é calculada sobre as matrículas com cor
      -- declarada (antes, sobre o total: a não declarada saía da soma dos
      -- quadrados e ficava no denominador, e quem não declarava parecia
      -- diverso). Com menos de metade declarada, a parte racial fica NULL e o
      -- peso dela (0,35) é redistribuído entre as outras três.
      SELECT
          p.nu_ano_censo,
          p.co_entidade,
          ROUND(
              CASE
                  WHEN p.racial IS NOT NULL
                  THEN 0.35 * p.racial * 10 + 0.25 * p.genero * 10 + 0.20 * p.inclusao * 10 + 0.20 * p.eja * 10
                  ELSE (0.25 * p.genero * 10 + 0.20 * p.inclusao * 10 + 0.20 * p.eja * 10) / 0.65
              END
          , 2) AS score_diversidade_discente
      FROM (
          SELECT
              m.nu_ano_censo,
              m.co_entidade,
              CASE
                  WHEN m.decl > 0 AND m.decl >= 0.5 * m.qt_mat_bas
                  THEN 1 - ( POWER(COALESCE(m.qt_mat_bas_branca,0)::numeric   / m.decl, 2) +
                             POWER(COALESCE(m.qt_mat_bas_preta,0)::numeric    / m.decl, 2) +
                             POWER(COALESCE(m.qt_mat_bas_parda,0)::numeric    / m.decl, 2) +
                             POWER(COALESCE(m.qt_mat_bas_amarela,0)::numeric  / m.decl, 2) +
                             POWER(COALESCE(m.qt_mat_bas_indigena,0)::numeric / m.decl, 2) )
              END AS racial,
              2 * LEAST(1, LEAST(COALESCE(m.qt_mat_bas_fem,0)::numeric, COALESCE(m.qt_mat_bas_masc,0)::numeric) / m.qt_mat_bas) AS genero,
              -- #459: inclusão = alunos da educação especial em classe comum.
              LEAST(1, COALESCE(m.qt_mat_esp_cc,0)::numeric / m.qt_mat_bas) AS inclusao,
              LEAST(1, COALESCE(m.qt_mat_eja,0)::numeric / m.qt_mat_bas) AS eja
          FROM (
              -- colunas explícitas: um mm.* põe na definição as de turno
              -- (qt_mat_bas_d/dm/dv), que o verify da #459 proíbe.
              SELECT mm.nu_ano_censo, mm.co_entidade, mm.qt_mat_bas,
                     mm.qt_mat_bas_branca, mm.qt_mat_bas_preta, mm.qt_mat_bas_parda,
                     mm.qt_mat_bas_amarela, mm.qt_mat_bas_indigena,
                     mm.qt_mat_bas_fem, mm.qt_mat_bas_masc, mm.qt_mat_esp_cc, mm.qt_mat_eja,
                     ( COALESCE(mm.qt_mat_bas_branca,0) + COALESCE(mm.qt_mat_bas_preta,0) +
                       COALESCE(mm.qt_mat_bas_parda,0) + COALESCE(mm.qt_mat_bas_amarela,0) +
                       COALESCE(mm.qt_mat_bas_indigena,0) )::numeric AS decl
                FROM clean.censo_matriculas mm
               WHERE mm.qt_mat_bas > 0       -- #467: sem matrícula, sem o índice
          ) m
      ) p
  ),
  -- ========== 6. SCORE CAPACIDADE GESTORA ==========
  score_gestao AS (
      SELECT
          g.nu_ano_censo,
          g.co_entidade,
          ROUND(
              -- 1. Qualificação do gestor (média entre graduação e pós)
              0.3 * (
                  ( CASE WHEN g.qt_gest_bas > 0
                         THEN LEAST(1, COALESCE(g.qt_gest_bas_esco_sup_grad,0)::numeric / g.qt_gest_bas) * 10
                         ELSE 0 END
                  + CASE WHEN g.qt_gest_bas > 0
                         THEN LEAST(1, (COALESCE(g.qt_gest_bas_esco_sup_pos_espec,0) +
                                        COALESCE(g.qt_gest_bas_esco_sup_pos_mestra,0) +
                                        COALESCE(g.qt_gest_bas_esco_sup_pos_douto,0))::numeric / g.qt_gest_bas) * 10
                         ELSE 0 END
                  ) / 2.0
              ) +
              -- 2. Especialização em gestão
              0.2 * ( CASE WHEN g.qt_gest_bas > 0
                           THEN LEAST(1, COALESCE(g.qt_gest_bas_espec_gestao,0)::numeric / g.qt_gest_bas) * 10
                           ELSE 0 END
                     ) +
              -- 3. Proporção gestor/aluno
              0.2 * CASE
                  WHEN g.qt_gest_bas > 0 AND COALESCE(m.qt_mat_bas, 0) > 0
                  THEN 10 * LEAST(1, 200.0 * g.qt_gest_bas / m.qt_mat_bas)
                  ELSE 0
              END +
              -- 4. Órgãos colegiados
              0.2 * ( LEAST(1, COALESCE(o.qt_colegiados,0) / 5.0) * 10 ) +
              -- 5. Acesso meritocrático ao cargo
              0.1 * ( CASE WHEN g.qt_gest_bas > 0
                           THEN LEAST(1, (COALESCE(g.qt_gest_bas_acesso_cargo_conca,0) +
                                          COALESCE(g.qt_gest_bas_acesso_cargo_eleic,0) +
                                          COALESCE(g.qt_gest_bas_acesso_cargo_p_sel,0))::numeric / g.qt_gest_bas) * 10
                           ELSE 0 END
                     )
          , 2) AS score_capacidade_gestora
      FROM clean.censo_gestor g
      LEFT JOIN clean.censo_matriculas m
          ON g.co_entidade = m.co_entidade AND g.nu_ano_censo = m.nu_ano_censo
      LEFT JOIN (
          SELECT
              co_entidade,
              nu_ano_censo,
              ( COALESCE(in_orgao_ass_pais,0) +
                COALESCE(in_orgao_ass_pais_mestres,0) +
                COALESCE(in_orgao_conselho_escolar,0) +
                COALESCE(in_orgao_gremio_estudantil,0) +
                COALESCE(in_orgao_outros,0) ) AS qt_colegiados
          FROM clean.censo_escolas
          WHERE tp_situacao_funcionamento = 1
      ) o ON g.co_entidade = o.co_entidade AND g.nu_ano_censo = o.nu_ano_censo
      WHERE g.qt_gest_bas > 0         -- #467: sem gestor, sem o índice
  ),

  -- ========== 7. SCORE SUSTENTABILIDADE ==========
  score_sustentabilidade AS (
      SELECT
          nu_ano_censo,
          co_entidade,
          ROUND(
              ( CASE WHEN COALESCE(in_energia_renovavel,0) = 1 THEN 10 ELSE 0 END +
                CASE WHEN COALESCE(in_tratamento_lixo_reciclagem,0) = 1 OR COALESCE(in_tratamento_lixo_reutiliza,0) = 1 THEN 10 ELSE 0 END +
                ( (CASE WHEN COALESCE(in_area_verde,0) = 1 THEN 10 ELSE 0 END) +
                  (CASE WHEN COALESCE(in_area_plantio,0) = 1 THEN 10 ELSE 0 END) ) / 2.0 +
                CASE WHEN COALESCE(in_educ_ambiental,0) = 1 OR COALESCE(in_educ_amb_conteudo,0)=1 OR
                           COALESCE(in_educ_amb_curricular,0)=1 OR COALESCE(in_educ_amb_eixo,0)=1 OR
                           COALESCE(in_educ_amb_eventos,0)=1 OR COALESCE(in_educ_amb_projetos,0)=1
                      THEN 10 ELSE 0 END
              ) / 4.0
          , 2) AS score_sustentabilidade
      FROM clean.censo_escolas
      WHERE tp_situacao_funcionamento = 1
  ),

  -- ========== 8. JUNÇÃO FINAL ==========
  -- #467: atendimento, docente, diversidade e gestora ficam NULL quando falta
  -- o registro de que dependem (vazio ≠ zero, #154). Infraestrutura e
  -- sustentabilidade vêm do cadastro da escola, sempre presente.
  scores_juntos AS (
      SELECT
          b.nu_ano_censo,
          b.co_entidade,
          cap.score_capacidade_atendimento,
          COALESCE(inf.score_infraestrutura, 0) AS score_infraestrutura,
          doc.score_capacitacao_docente,
          div.score_diversidade_discente,
          ges.score_capacidade_gestora,
          COALESCE(sus.score_sustentabilidade, 0) AS score_sustentabilidade,
          -- Data/hora da última atualização
          NOW() AS data_atualizacao
      FROM escolas_base b
      LEFT JOIN score_capacidade cap ON b.co_entidade = cap.co_entidade AND b.nu_ano_censo = cap.nu_ano_censo
      LEFT JOIN score_infra inf ON b.co_entidade = inf.co_entidade AND b.nu_ano_censo = inf.nu_ano_censo
      LEFT JOIN score_docente doc ON b.co_entidade = doc.co_entidade AND b.nu_ano_censo = doc.nu_ano_censo
      LEFT JOIN score_diversidade div ON b.co_entidade = div.co_entidade AND b.nu_ano_censo = div.nu_ano_censo
      LEFT JOIN score_gestao ges ON b.co_entidade = ges.co_entidade AND b.nu_ano_censo = ges.nu_ano_censo
      LEFT JOIN score_sustentabilidade sus ON b.co_entidade = sus.co_entidade AND b.nu_ano_censo = sus.nu_ano_censo
  )

  SELECT * FROM scores_juntos;

  -- ========== 9. ÍNDICES PARA CONSULTAS EFICIENTES ==========
  CREATE UNIQUE INDEX idx_mv_scores_pk ON clean.mv_escolas_scores (nu_ano_censo, co_entidade);
  CREATE INDEX idx_mv_scores_atendimento ON clean.mv_escolas_scores (score_capacidade_atendimento);
  CREATE INDEX idx_mv_scores_infra ON clean.mv_escolas_scores (score_infraestrutura);
  CREATE INDEX idx_mv_scores_docente ON clean.mv_escolas_scores (score_capacitacao_docente);
  CREATE INDEX idx_mv_scores_diversidade ON clean.mv_escolas_scores (score_diversidade_discente);
  CREATE INDEX idx_mv_scores_gestao ON clean.mv_escolas_scores (score_capacidade_gestora);
  CREATE INDEX idx_mv_scores_sustentabilidade ON clean.mv_escolas_scores (score_sustentabilidade);

  COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS 'ÍNDICE CANÔNICO do produto (#137): 6 scores 0-10 das escolas ativas, derivados do Censo Escolar (quanto maior, melhor). VERSÃO indices-v5 (2026-11-17; indices-v1 = fórmula original, 2026-06-04; v2 = inclusão da diversidade pela educação especial em classe comum, #459; v3 = escola sem registro de matrículas, docentes ou gestores fica sem o índice (NULL), #467; v4 = parte racial da diversidade sobre as matrículas com cor declarada, vazia com menos de metade declarada e peso redistribuído, #471; v5 = alunos por sala e por turno na capacidade de atendimento, #473). Mudança de fórmula sobe a versão aqui e em EduMaps::Model::Rank::School ($INDICES_VERSAO), #462. Consumido por analytics.ranking_escola (bin/ranking.pl), EduMaps::Model::Rank::School, SchoolEmbedding e View::ClusterEscola. Fórmula em docs/analises/ivet.md §2.2 (insumo do bloco A do IVET). Atualizar com REFRESH MATERIALIZED VIEW + refresh do ranking.';
  COMMENT ON COLUMN clean.mv_escolas_scores.nu_ano_censo     IS 'Ano do Censo Escolar de referencia dos scores.';
  COMMENT ON COLUMN clean.mv_escolas_scores.co_entidade      IS 'Codigo INEP da escola; liga os scores aos demais dados.';
  COMMENT ON COLUMN clean.mv_escolas_scores.data_atualizacao IS 'Momento da materializacao; indica a frescura dos scores.';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_capacidade_atendimento IS 'Base: alunos por sala e por turno (#473), diversidade de etapas, tempo integral, alimentação. NULL sem matrícula (#467).';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_infraestrutura IS 'Média de quatro categorias: básico, pedagógico, acessibilidade, tecnologia.';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_capacitacao_docente IS 'Formação superior, pós-graduação, vínculo efetivo, especializações. NULL sem docente (#467).';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_diversidade_discente IS 'Diversidade de cor/raça sobre as matrículas com cor declarada (#471; vazia com menos de metade declarada, peso redistribuído), equilíbrio de gênero, inclusão (educação especial em classe comum, #459) e oferta de EJA. NULL sem matrícula (#467).';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_capacidade_gestora IS 'Qualificação dos gestores, formação em gestão, proporção gestor/aluno, órgãos colegiados, acesso meritocrático. NULL sem gestor (#467).';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_sustentabilidade IS 'Energia renovável, gestão de resíduos, área verde/plantio, educação ambiental.';

  GRANT SELECT ON clean.mv_escolas_scores TO edumaps_leitor;

COMMIT;
