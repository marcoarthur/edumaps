-- Deploy edumaps:ideb_analytics to pg
-- requires: raw_inep
-- requires: raw_municipios_sp
-- requires: raw_escolas


BEGIN;

  --
  -- FUNÇÃO: clean.inep_despivotar_series_historicas
  -- DESCRIÇÃO: Despivota a tabela INEP transformando colunas anuais em linhas temporais
  --            Converte a estrutura wide (colunas por ano) para long (linhas por ano)
  --            Permite análise temporal completa dos indicadores educacionais
  -- PARÂMETROS:
  --   p_id_escola: Filtro opcional por ID da escola (NULL para todas as escolas)
  -- RETORNA: Série histórica com indicadores por ano e série desde 2005
  --
  CREATE OR REPLACE FUNCTION clean.inep_despivotar_series_historicas(
      p_id_escola BIGINT DEFAULT NULL
  )
  RETURNS TABLE(
      id_escola BIGINT,
      ano INTEGER,
      serie TEXT,
      aprovacao NUMERIC,
      indicador_rendimento NUMERIC,
      nota_matematica NUMERIC,
      nota_portugues NUMERIC,
      nota_media NUMERIC,
      observado NUMERIC,
      projecao NUMERIC
  ) 
  LANGUAGE plpgsql
  AS $$
  BEGIN
      RETURN QUERY
      WITH anos AS (
          SELECT UNNEST(ARRAY[2005,2007,2009,2011,2013,2015,2017,2019,2021,2023]) AS ano
      ),
      series AS (
          SELECT UNNEST(ARRAY['si_4', 'si', '1', '2', '3', '4']) AS serie
      )
      
      SELECT 
          i.id_escola,
          a.ano,
          s.serie,
          -- Aprovação por série/ano
          CASE 
              WHEN s.serie = 'si_4' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_si_4
                      WHEN 2007 THEN i.vl_aprovacao_2007_si_4
                      WHEN 2009 THEN i.vl_aprovacao_2009_si_4
                      WHEN 2011 THEN i.vl_aprovacao_2011_si_4
                      WHEN 2013 THEN i.vl_aprovacao_2013_si_4
                      WHEN 2015 THEN i.vl_aprovacao_2015_si_4
                      WHEN 2017 THEN i.vl_aprovacao_2017_si_4
                      WHEN 2019 THEN i.vl_aprovacao_2019_si_4
                      WHEN 2021 THEN i.vl_aprovacao_2021_si_4
                      WHEN 2023 THEN i.vl_aprovacao_2023_si_4
                  END
              WHEN s.serie = 'si' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_si
                      WHEN 2007 THEN i.vl_aprovacao_2007_si
                      WHEN 2009 THEN i.vl_aprovacao_2009_si
                      WHEN 2011 THEN i.vl_aprovacao_2011_si
                      WHEN 2013 THEN i.vl_aprovacao_2013_si
                      WHEN 2015 THEN i.vl_aprovacao_2015_si
                      WHEN 2017 THEN i.vl_aprovacao_2017_si
                      WHEN 2019 THEN i.vl_aprovacao_2019_si
                      WHEN 2021 THEN i.vl_aprovacao_2021_si
                      WHEN 2023 THEN i.vl_aprovacao_2023_si
                  END
              WHEN s.serie = '1' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_1
                      WHEN 2007 THEN i.vl_aprovacao_2007_1
                      WHEN 2009 THEN i.vl_aprovacao_2009_1
                      WHEN 2011 THEN i.vl_aprovacao_2011_1
                      WHEN 2013 THEN i.vl_aprovacao_2013_1
                      WHEN 2015 THEN i.vl_aprovacao_2015_1
                      WHEN 2017 THEN i.vl_aprovacao_2017_1
                      WHEN 2019 THEN i.vl_aprovacao_2019_1
                      WHEN 2021 THEN i.vl_aprovacao_2021_1
                      WHEN 2023 THEN i.vl_aprovacao_2023_1
                  END
              WHEN s.serie = '2' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_2
                      WHEN 2007 THEN i.vl_aprovacao_2007_2
                      WHEN 2009 THEN i.vl_aprovacao_2009_2
                      WHEN 2011 THEN i.vl_aprovacao_2011_2
                      WHEN 2013 THEN i.vl_aprovacao_2013_2
                      WHEN 2015 THEN i.vl_aprovacao_2015_2
                      WHEN 2017 THEN i.vl_aprovacao_2017_2
                      WHEN 2019 THEN i.vl_aprovacao_2019_2
                      WHEN 2021 THEN i.vl_aprovacao_2021_2
                      WHEN 2023 THEN i.vl_aprovacao_2023_2
                  END
              WHEN s.serie = '3' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_3
                      WHEN 2007 THEN i.vl_aprovacao_2007_3
                      WHEN 2009 THEN i.vl_aprovacao_2009_3
                      WHEN 2011 THEN i.vl_aprovacao_2011_3
                      WHEN 2013 THEN i.vl_aprovacao_2013_3
                      WHEN 2015 THEN i.vl_aprovacao_2015_3
                      WHEN 2017 THEN i.vl_aprovacao_2017_3
                      WHEN 2019 THEN i.vl_aprovacao_2019_3
                      WHEN 2021 THEN i.vl_aprovacao_2021_3
                      WHEN 2023 THEN i.vl_aprovacao_2023_3
                  END
              WHEN s.serie = '4' THEN 
                  CASE a.ano
                      WHEN 2005 THEN i.vl_aprovacao_2005_4
                      WHEN 2007 THEN i.vl_aprovacao_2007_4
                      WHEN 2009 THEN i.vl_aprovacao_2009_4
                      WHEN 2011 THEN i.vl_aprovacao_2011_4
                      WHEN 2013 THEN i.vl_aprovacao_2013_4
                      WHEN 2015 THEN i.vl_aprovacao_2015_4
                      WHEN 2017 THEN i.vl_aprovacao_2017_4
                      WHEN 2019 THEN i.vl_aprovacao_2019_4
                      WHEN 2021 THEN i.vl_aprovacao_2021_4
                      WHEN 2023 THEN i.vl_aprovacao_2023_4
                  END
          END AS aprovacao,
          
          -- Indicador de rendimento (por ano, não por série)
          CASE a.ano
              WHEN 2005 THEN i.vl_indicador_rend_2005
              WHEN 2007 THEN i.vl_indicador_rend_2007
              WHEN 2009 THEN i.vl_indicador_rend_2009
              WHEN 2011 THEN i.vl_indicador_rend_2011
              WHEN 2013 THEN i.vl_indicador_rend_2013
              WHEN 2015 THEN i.vl_indicador_rend_2015
              WHEN 2017 THEN i.vl_indicador_rend_2017
              WHEN 2019 THEN i.vl_indicador_rend_2019
              WHEN 2021 THEN i.vl_indicador_rend_2021
              WHEN 2023 THEN i.vl_indicador_rend_2023
          END AS indicador_rendimento,
          
          -- Notas (por ano, não por série)
          CASE a.ano
              WHEN 2005 THEN i.vl_nota_matematica_2005
              WHEN 2007 THEN i.vl_nota_matematica_2007
              WHEN 2009 THEN i.vl_nota_matematica_2009
              WHEN 2011 THEN i.vl_nota_matematica_2011
              WHEN 2013 THEN i.vl_nota_matematica_2013
              WHEN 2015 THEN i.vl_nota_matematica_2015
              WHEN 2017 THEN i.vl_nota_matematica_2017
              WHEN 2019 THEN i.vl_nota_matematica_2019
              WHEN 2021 THEN i.vl_nota_matematica_2021
              WHEN 2023 THEN i.vl_nota_matematica_2023
          END AS nota_matematica,
          
          CASE a.ano
              WHEN 2005 THEN i.vl_nota_portugues_2005
              WHEN 2007 THEN i.vl_nota_portugues_2007
              WHEN 2009 THEN i.vl_nota_portugues_2009
              WHEN 2011 THEN i.vl_nota_portugues_2011
              WHEN 2013 THEN i.vl_nota_portugues_2013
              WHEN 2015 THEN i.vl_nota_portugues_2015
              WHEN 2017 THEN i.vl_nota_portugues_2017
              WHEN 2019 THEN i.vl_nota_portugues_2019
              WHEN 2021 THEN i.vl_nota_portugues_2021
              WHEN 2023 THEN i.vl_nota_portugues_2023
          END AS nota_portugues,
          
          CASE a.ano
              WHEN 2005 THEN i.vl_nota_media_2005
              WHEN 2007 THEN i.vl_nota_media_2007
              WHEN 2009 THEN i.vl_nota_media_2009
              WHEN 2011 THEN i.vl_nota_media_2011
              WHEN 2013 THEN i.vl_nota_media_2013
              WHEN 2015 THEN i.vl_nota_media_2015
              WHEN 2017 THEN i.vl_nota_media_2017
              WHEN 2019 THEN i.vl_nota_media_2019
              WHEN 2021 THEN i.vl_nota_media_2021
              WHEN 2023 THEN i.vl_nota_media_2023
          END AS nota_media,
          
          -- Observado e projeção
          CASE a.ano
              WHEN 2005 THEN i.vl_observado_2005
              WHEN 2007 THEN i.vl_observado_2007
              WHEN 2009 THEN i.vl_observado_2009
              WHEN 2011 THEN i.vl_observado_2011
              WHEN 2013 THEN i.vl_observado_2013
              WHEN 2015 THEN i.vl_observado_2015
              WHEN 2017 THEN i.vl_observado_2017
              WHEN 2019 THEN i.vl_observado_2019
              WHEN 2021 THEN i.vl_observado_2021
              WHEN 2023 THEN i.vl_observado_2023
          END AS observado,
          
          CASE a.ano
              WHEN 2007 THEN i.vl_projecao_2007
              WHEN 2009 THEN i.vl_projecao_2009
              WHEN 2011 THEN i.vl_projecao_2011
              WHEN 2013 THEN i.vl_projecao_2013
              WHEN 2015 THEN i.vl_projecao_2015
              WHEN 2017 THEN i.vl_projecao_2017
              WHEN 2019 THEN i.vl_projecao_2019
              WHEN 2021 THEN i.vl_projecao_2021
          END AS projecao
          
      FROM clean.inep i
      CROSS JOIN anos a
      CROSS JOIN series s
      WHERE (p_id_escola IS NULL OR i.id_escola = p_id_escola)
      ORDER BY i.id_escola, a.ano, s.serie;
  END;
  $$;

  --
  -- FUNÇÃO: clean.inep_notas_evolucao
  -- DESCRIÇÃO: Retorna a evolução temporal das notas (SAEB/IDEB) para uma ou todas as escolas
  --            Foca nas métricas principais: notas de matemática, português e IDEB
  --            Inclui comparação entre valores observados e projetados
  -- PARÂMETROS:
  --   p_id_escola: Filtro opcional por ID da escola (NULL para todas as escolas)
  -- RETORNA: Série histórica de notas padronizada para análise temporal
  --
  CREATE OR REPLACE FUNCTION clean.inep_notas_evolucao(
      p_id_escola BIGINT DEFAULT NULL
  )
  RETURNS TABLE(
      id_escola BIGINT,
      ano INTEGER,
      nota_matematica NUMERIC,
      nota_portugues NUMERIC,
      nota_media NUMERIC,
      observado NUMERIC,
      projecao NUMERIC,
      indicador_rendimento NUMERIC
  ) 
  LANGUAGE sql
  AS $$
      SELECT 
          id_escola,
          ano,
          CASE ano
              WHEN 2005 THEN vl_nota_matematica_2005
              WHEN 2007 THEN vl_nota_matematica_2007
              WHEN 2009 THEN vl_nota_matematica_2009
              WHEN 2011 THEN vl_nota_matematica_2011
              WHEN 2013 THEN vl_nota_matematica_2013
              WHEN 2015 THEN vl_nota_matematica_2015
              WHEN 2017 THEN vl_nota_matematica_2017
              WHEN 2019 THEN vl_nota_matematica_2019
              WHEN 2021 THEN vl_nota_matematica_2021
              WHEN 2023 THEN vl_nota_matematica_2023
          END AS nota_matematica,
          CASE ano
              WHEN 2005 THEN vl_nota_portugues_2005
              WHEN 2007 THEN vl_nota_portugues_2007
              WHEN 2009 THEN vl_nota_portugues_2009
              WHEN 2011 THEN vl_nota_portugues_2011
              WHEN 2013 THEN vl_nota_portugues_2013
              WHEN 2015 THEN vl_nota_portugues_2015
              WHEN 2017 THEN vl_nota_portugues_2017
              WHEN 2019 THEN vl_nota_portugues_2019
              WHEN 2021 THEN vl_nota_portugues_2021
              WHEN 2023 THEN vl_nota_portugues_2023
          END AS nota_portugues,
          CASE ano
              WHEN 2005 THEN vl_nota_media_2005
              WHEN 2007 THEN vl_nota_media_2007
              WHEN 2009 THEN vl_nota_media_2009
              WHEN 2011 THEN vl_nota_media_2011
              WHEN 2013 THEN vl_nota_media_2013
              WHEN 2015 THEN vl_nota_media_2015
              WHEN 2017 THEN vl_nota_media_2017
              WHEN 2019 THEN vl_nota_media_2019
              WHEN 2021 THEN vl_nota_media_2021
              WHEN 2023 THEN vl_nota_media_2023
          END AS nota_media,
          CASE ano
              WHEN 2005 THEN vl_observado_2005
              WHEN 2007 THEN vl_observado_2007
              WHEN 2009 THEN vl_observado_2009
              WHEN 2011 THEN vl_observado_2011
              WHEN 2013 THEN vl_observado_2013
              WHEN 2015 THEN vl_observado_2015
              WHEN 2017 THEN vl_observado_2017
              WHEN 2019 THEN vl_observado_2019
              WHEN 2021 THEN vl_observado_2021
              WHEN 2023 THEN vl_observado_2023
          END AS observado,
          CASE ano
              WHEN 2007 THEN vl_projecao_2007
              WHEN 2009 THEN vl_projecao_2009
              WHEN 2011 THEN vl_projecao_2011
              WHEN 2013 THEN vl_projecao_2013
              WHEN 2015 THEN vl_projecao_2015
              WHEN 2017 THEN vl_projecao_2017
              WHEN 2019 THEN vl_projecao_2019
              WHEN 2021 THEN vl_projecao_2021
          END AS projecao,
          CASE ano
              WHEN 2005 THEN vl_indicador_rend_2005
              WHEN 2007 THEN vl_indicador_rend_2007
              WHEN 2009 THEN vl_indicador_rend_2009
              WHEN 2011 THEN vl_indicador_rend_2011
              WHEN 2013 THEN vl_indicador_rend_2013
              WHEN 2015 THEN vl_indicador_rend_2015
              WHEN 2017 THEN vl_indicador_rend_2017
              WHEN 2019 THEN vl_indicador_rend_2019
              WHEN 2021 THEN vl_indicador_rend_2021
              WHEN 2023 THEN vl_indicador_rend_2023
          END AS indicador_rendimento
      FROM clean.inep
      CROSS JOIN (VALUES 
          (2005),(2007),(2009),(2011),(2013),
          (2015),(2017),(2019),(2021),(2023)
      ) AS anos(ano)
      WHERE (p_id_escola IS NULL OR id_escola = p_id_escola)
      ORDER BY id_escola, ano;
  $$;

  --
  -- FUNÇÃO: clean.inep_series_historicas_municipio
  -- DESCRIÇÃO: Retorna séries históricas completas para todas as escolas de um município
  --            Combina dados demográficos das escolas com evolução temporal de indicadores
  --            Ideal para análise comparativa intra-municipal e dashboards
  -- PARÂMETROS:
  --   p_codigo_ibge: Código IBGE do município (7 dígitos)
  --   p_limit_escolas: Limite opcional de escolas (útil para testes)
  -- RETORNA: Dados consolidados por escola e ano com contexto municipal
  --
  CREATE OR REPLACE FUNCTION clean.inep_series_historicas_municipio(
      p_codigo_ibge VARCHAR(7) DEFAULT NULL,
      p_limit_escolas INTEGER DEFAULT NULL
  )
  RETURNS TABLE(
      -- Dados da escola
      id_escola BIGINT,
      no_escola TEXT,
      rede TEXT,
      codigo_ibge VARCHAR(7),
      no_municipio TEXT,
      sg_uf TEXT,
      -- Série histórica
      ano INTEGER,
      nota_matematica NUMERIC,
      nota_portugues NUMERIC,
      nota_media NUMERIC,
      observado NUMERIC,
      projecao NUMERIC,
      indicador_rendimento NUMERIC,
      -- Taxas de aprovação (média das séries iniciais)
      aprovacao_media NUMERIC
  ) 
  LANGUAGE plpgsql
  AS $$
  BEGIN
      RETURN QUERY
      WITH escolas_municipio AS (
          SELECT 
              i.id_escola,
              i.no_escola,
              i.rede,
              i.codigo_ibge,
              i.no_municipio,
              i.sg_uf
          FROM clean.inep i
          WHERE 
              (p_codigo_ibge IS NULL OR i.codigo_ibge = p_codigo_ibge)
              AND (p_limit_escolas IS NULL OR i.id_escola IN (
                  SELECT ii.id_escola 
                  FROM clean.inep ii
                  WHERE (p_codigo_ibge IS NULL OR i.codigo_ibge = p_codigo_ibge)
                  LIMIT p_limit_escolas
              ))
      )
      SELECT 
          em.id_escola,
          em.no_escola,
          em.rede,
          em.codigo_ibge,
          em.no_municipio,
          em.sg_uf,
          nh.ano,
          nh.nota_matematica,
          nh.nota_portugues,
          nh.nota_media,
          nh.observado,
          nh.projecao,
          nh.indicador_rendimento,
          -- Taxa de aprovação média (si_4) para o ano
          CASE nh.ano
              WHEN 2005 THEN i.vl_aprovacao_2005_si_4
              WHEN 2007 THEN i.vl_aprovacao_2007_si_4
              WHEN 2009 THEN i.vl_aprovacao_2009_si_4
              WHEN 2011 THEN i.vl_aprovacao_2011_si_4
              WHEN 2013 THEN i.vl_aprovacao_2013_si_4
              WHEN 2015 THEN i.vl_aprovacao_2015_si_4
              WHEN 2017 THEN i.vl_aprovacao_2017_si_4
              WHEN 2019 THEN i.vl_aprovacao_2019_si_4
              WHEN 2021 THEN i.vl_aprovacao_2021_si_4
              WHEN 2023 THEN i.vl_aprovacao_2023_si_4
          END AS aprovacao_media
      FROM escolas_municipio em
      CROSS JOIN LATERAL clean.inep_notas_evolucao(em.id_escola) AS nh
      LEFT JOIN clean.inep i ON em.id_escola = i.id_escola
      ORDER BY em.no_escola, nh.ano;
  END;
  $$;

  --
  -- FUNÇÃO: clean.inep_estatisticas_municipio
  -- DESCRIÇÃO: Calcula estatísticas consolidadas do IDEB para um município
  --            Fornece visão agregada com médias, extremos e métricas de evolução
  --            Essencial para relatórios municipais e benchmarking
  -- PARÂMETROS:
  --   p_codigo_ibge: Código IBGE do município (7 dígitos)
  -- RETORNA: Estatísticas agregadas por ano com indicadores de performance
  --
  CREATE OR REPLACE FUNCTION clean.inep_estatisticas_municipio(
      p_codigo_ibge VARCHAR(7)
  )
  RETURNS TABLE(
      ano INTEGER,
      n_escolas INTEGER,
      media_matematica NUMERIC,
      media_portugues NUMERIC,
      media_ideb NUMERIC,
      media_aprovacao NUMERIC,
      melhor_ideb NUMERIC,
      pior_ideb NUMERIC,
      escolas_melhoraram INTEGER,
      escolas_pioraram INTEGER
  ) 
  LANGUAGE sql
  AS $$
      WITH dados_ano AS (
          SELECT 
              ano,
              id_escola,
              nota_matematica,
              nota_portugues,
              nota_media,
              aprovacao_media
          FROM clean.inep_series_historicas_municipio(p_codigo_ibge)
      ),
      evolucao AS (
          SELECT 
              id_escola,
              -- Compara 2023 com 2005 (quando disponível)
              MAX(CASE WHEN ano = 2023 THEN nota_media END) as ideb_2023,
              MAX(CASE WHEN ano = 2005 THEN nota_media END) as ideb_2005
          FROM dados_ano
          GROUP BY id_escola
      )
      SELECT 
          da.ano,
          COUNT(DISTINCT da.id_escola) as n_escolas,
          ROUND(AVG(da.nota_matematica), 2) as media_matematica,
          ROUND(AVG(da.nota_portugues), 2) as media_portugues,
          ROUND(AVG(da.nota_media), 2) as media_ideb,
          ROUND(AVG(da.aprovacao_media), 2) as media_aprovacao,
          ROUND(MAX(da.nota_media), 2) as melhor_ideb,
          ROUND(MIN(da.nota_media), 2) as pior_ideb,
          COUNT(CASE WHEN e.ideb_2023 > e.ideb_2005 THEN 1 END) as escolas_melhoraram,
          COUNT(CASE WHEN e.ideb_2023 < e.ideb_2005 THEN 1 END) as escolas_pioraram
      FROM dados_ano da
      LEFT JOIN evolucao e ON da.id_escola = e.id_escola
      WHERE da.nota_media IS NOT NULL
      GROUP BY da.ano
      ORDER BY da.ano;
  $$;

  -- Comentários para documentação do schema
  COMMENT ON FUNCTION clean.inep_despivotar_series_historicas(BIGINT) IS 
  'Despivota dados INEP transformando estrutura wide (colunas anuais) para long (linhas temporais).
  Retorna série histórica completa 2005-2023 com indicadores por série escolar.
  Uso: SELECT * FROM clean.inep_despivotar_series_historicas([id_escola])';

  COMMENT ON FUNCTION clean.inep_notas_evolucao(BIGINT) IS 
  'Retorna evolução temporal das notas SAEB/IDEB para análise de performance educacional.
  Inclui comparação entre valores observados e projetados para monitoramento de metas.
  Uso: SELECT * FROM clean.inep_notas_evolucao([id_escola])';

  COMMENT ON FUNCTION clean.inep_series_historicas_municipio(VARCHAR, INTEGER) IS 
  'Consulta consolidada para análise municipal - retorna séries históricas de todas as escolas.
  Combina dados demográficos com indicadores educacionais para dashboards municipais.
  Uso: SELECT * FROM clean.inep_series_historicas_municipio(''355540''[, limite_escolas])';

  COMMENT ON FUNCTION clean.inep_estatisticas_municipio(VARCHAR) IS 
  'Estatísticas agregadas do IDEB por município - médias, extremos e métricas de evolução.
  Essencial para relatórios de gestão educacional e benchmarking municipal.
  Uso: SELECT * FROM clean.inep_estatisticas_municipio(''355540'')';

COMMIT;
