-- Deploy edumaps:analytics_municipios_consolidado to pg

BEGIN;

  -- View materializada consolidada para análise de municípios (RÁPIDA)
  CREATE MATERIALIZED VIEW analytics.mv_municipios_consolidado AS
  WITH 
  -- Base de municípios
  municipios_base AS (
      SELECT DISTINCT 
          co_municipio,
          no_municipio,
          sg_uf,
          no_regiao,
          co_regiao
      FROM clean.censo_escolas
      WHERE co_municipio IS NOT NULL
  ),

  -- Agregados do Censo Escolar
  escolas_agregado AS (
      SELECT 
          e.co_municipio,
          COUNT(DISTINCT e.co_entidade) AS total_escolas,
          COUNT(DISTINCT CASE WHEN e.tp_dependencia IN (1,2,3) THEN e.co_entidade END) AS escolas_publicas,
          COUNT(DISTINCT CASE WHEN e.tp_dependencia = 4 THEN e.co_entidade END) AS escolas_privadas,
          COUNT(DISTINCT CASE WHEN e.tp_localizacao = 1 THEN e.co_entidade END) AS escolas_urbanas,
          COUNT(DISTINCT CASE WHEN e.tp_localizacao = 2 THEN e.co_entidade END) AS escolas_rurais,
          SUM(COALESCE(m.qt_mat_bas, 0)) AS total_alunos,
          SUM(COALESCE(m.qt_mat_inf, 0)) AS alunos_infantil,
          SUM(COALESCE(m.qt_mat_fund, 0)) AS alunos_fundamental,
          SUM(COALESCE(m.qt_mat_med, 0)) AS alunos_medio,
          SUM(COALESCE(m.qt_mat_eja, 0)) AS alunos_eja,
          SUM(COALESCE(d.qt_doc_bas, 0)) AS total_docentes,
          ROUND(SUM(COALESCE(d.qt_doc_bas_esco_sup_grad, 0))::NUMERIC / 
                NULLIF(SUM(COALESCE(d.qt_doc_bas, 0)), 0) * 100, 2) AS perc_docentes_superior,
          ROUND(SUM(COALESCE(d.qt_doc_bas_vinculo_concur, 0))::NUMERIC / 
                NULLIF(SUM(COALESCE(d.qt_doc_bas, 0)), 0) * 100, 2) AS perc_docentes_concursados
      FROM clean.censo_escolas e
      LEFT JOIN clean.censo_matriculas m ON m.co_entidade = e.co_entidade AND m.nu_ano_censo = 2025
      LEFT JOIN clean.censo_docentes d ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = 2025
      GROUP BY e.co_municipio
  ),

  -- Scores de infraestrutura
  scores_agregado AS (
      SELECT 
          e.co_municipio,
          ROUND(AVG(s.score_infra_essencial), 2) AS score_infra_medio,
          ROUND(AVG(s.score_tecnologia), 2) AS score_tecnologia_medio,
          ROUND(AVG(s.score_acessibilidade), 2) AS score_acessibilidade_medio,
          ROUND(AVG(s.score_gestao_participacao), 2) AS score_gestao_medio
      FROM clean.censo_escolas e
      JOIN clean.censo_escolas_scores s ON s.co_entidade = e.co_entidade
      GROUP BY e.co_municipio
  ),

  -- IDEB por município
  ideb_agregado AS (
      SELECT 
          co_municipio,
          MAX(CASE WHEN etapa = 'fundamental_i' THEN ideb_observado END) AS ideb_fund_i,
          MAX(CASE WHEN etapa = 'fundamental_ii' THEN ideb_observado END) AS ideb_fund_ii,
          MAX(CASE WHEN etapa = 'ensino_medio' THEN ideb_observado END) AS ideb_medio,
          MAX(ano) AS ano_ideb
      FROM clean.ideb_notas_escolas
      WHERE ideb_observado IS NOT NULL
      GROUP BY co_municipio
  ),

  -- Dados populacionais
  populacao_agregado AS (
      SELECT DISTINCT ON (codigo_ibge)
          codigo_ibge,
          populacao_estimada,
          pop_0_a_14,
          pop_15_a_24,
          pop_25_a_59,
          pop_60_mais
      FROM clean.populacao_municipal
      ORDER BY codigo_ibge, linha_original DESC
  ),

  -- Dados econômicos com percentuais setoriais (priorizando ano completo)
  -- Primeiro, encontra o ano mais recente que tem dados de percentuais
  economia_agregado AS (
      SELECT 
          d.codigo_ibge,
          d.pib_total,
          d.agro_percent,
          d.industria_percent,
          d.servicos_percent,
          d.governo_percent,
          d.ano AS ano_pib,
          -- PIB per capita
          ROUND((d.pib_total / NULLIF(p.populacao_estimada, 0)) * 1000, 2) AS pib_per_capita
      FROM clean.dados_ibge d
      INNER JOIN populacao_agregado p ON p.codigo_ibge = d.codigo_ibge
      INNER JOIN (
          -- Subquery que pega o ano mais recente que tem dados de percentuais
          SELECT codigo_ibge, MAX(ano) AS max_ano
          FROM clean.dados_ibge
          WHERE agro_percent IS NOT NULL  -- ou qualquer um dos percentuais
          GROUP BY codigo_ibge
      ) latest ON latest.codigo_ibge = d.codigo_ibge AND latest.max_ano = d.ano
  )

  -- SELECT final
  SELECT 
      mb.co_municipio::text,
      mb.no_municipio,
      mb.sg_uf,
      mb.no_regiao,
      
      -- Educacionais
      COALESCE(ea.total_escolas, 0) AS total_escolas,
      COALESCE(ea.escolas_publicas, 0) AS escolas_publicas,
      COALESCE(ea.escolas_privadas, 0) AS escolas_privadas,
      COALESCE(ea.escolas_urbanas, 0) AS escolas_urbanas,
      COALESCE(ea.escolas_rurais, 0) AS escolas_rurais,
      COALESCE(ea.total_alunos, 0) AS total_alunos,
      COALESCE(ea.alunos_infantil, 0) AS alunos_infantil,
      COALESCE(ea.alunos_fundamental, 0) AS alunos_fundamental,
      COALESCE(ea.alunos_medio, 0) AS alunos_medio,
      COALESCE(ea.alunos_eja, 0) AS alunos_eja,
      COALESCE(ea.total_docentes, 0) AS total_docentes,
      ea.perc_docentes_superior,
      ea.perc_docentes_concursados,
      
      -- Scores
      sa.score_infra_medio,
      sa.score_tecnologia_medio,
      sa.score_acessibilidade_medio,
      sa.score_gestao_medio,
      
      -- IDEB
      ia.ideb_fund_i,
      ia.ideb_fund_ii,
      ia.ideb_medio,
      ia.ano_ideb,
      
      -- Demografia
      pe.populacao_estimada,
      pe.pop_0_a_14,
      pe.pop_15_a_24,
      pe.pop_25_a_59,
      pe.pop_60_mais,
      
      -- Economia (agora com percentuais preenchidos)
      ec.pib_total,
      ec.pib_per_capita,
      ec.agro_percent,
      ec.industria_percent,
      ec.servicos_percent,
      ec.governo_percent,
      ec.ano_pib,
      
      -- Indicadores derivados
      CASE 
          WHEN pe.populacao_estimada > 0 
          THEN ROUND((COALESCE(ea.total_alunos, 0)::NUMERIC / pe.populacao_estimada) * 1000, 2)
          ELSE NULL 
      END AS alunos_por_1000_hab,
      
      CASE 
          WHEN COALESCE(ea.total_docentes, 0) > 0 
          THEN ROUND(COALESCE(ea.total_alunos, 0)::NUMERIC / ea.total_docentes, 1)
          ELSE NULL 
      END AS alunos_por_docente,
      
      CASE 
          WHEN COALESCE(ea.total_escolas, 0) > 0 
          THEN ROUND(COALESCE(ea.total_alunos, 0)::NUMERIC / ea.total_escolas, 0)
          ELSE NULL 
      END AS alunos_por_escola

  FROM municipios_base mb
  LEFT JOIN escolas_agregado ea ON ea.co_municipio = mb.co_municipio
  LEFT JOIN scores_agregado sa ON sa.co_municipio = mb.co_municipio
  LEFT JOIN ideb_agregado ia ON ia.co_municipio = mb.co_municipio
  LEFT JOIN populacao_agregado pe ON pe.codigo_ibge = mb.co_municipio::text
  LEFT JOIN economia_agregado ec ON ec.codigo_ibge = mb.co_municipio::text;

  -- Recriar índices
  CREATE UNIQUE INDEX idx_mv_municipios_co_municipio ON analytics.mv_municipios_consolidado (co_municipio);
  CREATE INDEX idx_mv_municipios_uf ON analytics.mv_municipios_consolidado (sg_uf);
  CREATE INDEX idx_mv_municipios_ideb_fund_ii ON analytics.mv_municipios_consolidado (ideb_fund_ii) WHERE ideb_fund_ii IS NOT NULL;
  CREATE INDEX idx_mv_municipios_pib_per_capita ON analytics.mv_municipios_consolidado (pib_per_capita) WHERE pib_per_capita IS NOT NULL;
  CREATE INDEX idx_mv_municipios_populacao ON analytics.mv_municipios_consolidado (populacao_estimada) WHERE populacao_estimada IS NOT NULL;

  -- Comentários
  COMMENT ON MATERIALIZED VIEW analytics.mv_municipios_consolidado IS 'VIEW MATERIALIZADA - Visão consolidada para análise municipal. Dados educacionais (Censo Escolar 2025), desempenho (IDEB/SAEB), demografia (IBGE) e economia (PIB). Materializada para performance em análises repetidas.';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.co_municipio IS 'Código IBGE do município (7 dígitos)';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.total_escolas IS 'Total de escolas no município';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.total_alunos IS 'Total de matrículas na educação básica';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.total_docentes IS 'Total de docentes na educação básica';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.ideb_fund_ii IS 'IDEB dos anos finais do fundamental (último ano disponível)';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.pib_per_capita IS 'PIB per capita (em R$)';
  COMMENT ON COLUMN analytics.mv_municipios_consolidado.alunos_por_docente IS 'Relação aluno-docente (municipal)';

  -- Função para atualizar a view materializada (pode ser chamada via cron ou após imports)
  CREATE OR REPLACE FUNCTION analytics.refresh_municipios_consolidado()
  RETURNS TEXT AS $$
  DECLARE
      start_time TIMESTAMP;
      end_time TIMESTAMP;
  BEGIN
      start_time := clock_timestamp();
      
      -- Refresh da view materializada (CONCURRENTLY evita locks, mas requer índice único)
      REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_municipios_consolidado;
      
      end_time := clock_timestamp();
      
      RETURN format('View materializada atualizada em %s segundos', 
                    EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC(10,2));
  END;
  $$ LANGUAGE plpgsql;

  -- Comentário
  COMMENT ON FUNCTION analytics.refresh_municipios_consolidado() IS 'Atualiza a view materializada mv_municipios_consolidado com dados mais recentes. Retorna o tempo de execução.';

COMMIT;
