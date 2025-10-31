-- Deploy edumaps:analytics_acessibility_views to pg
-- requires: analytics_acessibility

BEGIN;
  -- 1. Geotag escolas com municipios 
  CREATE OR REPLACE VIEW analytics.escolas_filtradas AS
  SELECT 
      e.*,
      m.codigo_ibge as municipio_ibge,
      m.nome as municipio_nome
  FROM clean.escolas e
  JOIN clean.municipios_sp m ON ST_Within(e.geometry, m.geometry);

  -- 2. Função calcula metricas de acessibilidade escolas geotageadas
  -- Os filtros são aplicados diretamente na consulta que chama esta função
  CREATE OR REPLACE FUNCTION analytics.calcular_acessibilidade_filtrada(
      p_codigo_ibge VARCHAR(7),
      p_raio_km NUMERIC DEFAULT 5
  )
  RETURNS TABLE (
      percentual_cobertura DOUBLE PRECISION,
      area_coberta_km2 DOUBLE PRECISION,
      area_total_km2 DOUBLE PRECISION,
      n_escolas BIGINT,
      municipio_nome VARCHAR(250),
      codigo_ibge_municipio VARCHAR(7),
      cobertura GEOMETRY
  ) 
  LANGUAGE sql
  AS $$
      WITH municipio AS (
          SELECT 
              geometry, 
              nome, 
              COALESCE(area_km2, ST_Area(geometry::GEOGRAPHY) / 1000000) as area_total
          FROM clean.municipios_sp 
          WHERE codigo_ibge = p_codigo_ibge
      ),
      escolas_filtradas AS (
          SELECT *
          FROM analytics.escolas_filtradas
          WHERE municipio_ibge = p_codigo_ibge
      ),
      buffers AS (
          SELECT 
              ST_Union(ST_Buffer(geometry::GEOGRAPHY, p_raio_km * 1000)::GEOMETRY) as buffer_unido
          FROM escolas_filtradas
      ),
      area_coberta AS (
          SELECT 
              CASE 
                  WHEN b.buffer_unido IS NOT NULL THEN 
                      ST_Area(ST_Intersection(m.geometry, b.buffer_unido)::GEOGRAPHY) / 1000000
                  ELSE 0 
              END as area_km2
          FROM municipio m, buffers b
      )
      SELECT 
          (ac.area_km2 / m.area_total) * 100 as percentual_cobertura,
          ac.area_km2 as area_coberta_km2,
          m.area_total as area_total_km2,
          (SELECT COUNT(*) FROM escolas_filtradas) as n_escolas,
          m.nome as municipio_nome,
          p_codigo_ibge as codigo_ibge_municipio,
          b.buffer_unido as cobertura
      FROM municipio m, area_coberta ac, buffers b;
  $$;

  -- View materializada com métricas de acessibilidade de todos os municípios
  CREATE MATERIALIZED VIEW analytics.metricas_acessibilidade_municipios AS
  SELECT 
      codigo_ibge_municipio as codigo_ibge,
      municipio_nome as municipio,
      percentual_cobertura,
      area_coberta_km2,
      area_total_km2,
      n_escolas,
      -- Métricas derivadas
      CASE 
          WHEN area_total_km2 > 0 THEN n_escolas / area_total_km2 
          ELSE 0 
      END as densidade_escolas_km2,
      CASE 
          WHEN n_escolas > 0 THEN area_coberta_km2 / n_escolas 
          ELSE 0 
      END as area_coberta_por_escola,
      -- Categorização
      CASE 
          WHEN percentual_cobertura >= 90 THEN 'Muito Alta'
          WHEN percentual_cobertura >= 75 THEN 'Alta' 
          WHEN percentual_cobertura >= 50 THEN 'Média'
          WHEN percentual_cobertura >= 25 THEN 'Baixa'
          ELSE 'Muito Baixa'
      END as categoria_cobertura,
      NOW() as atualizado_em
  FROM analytics.calcular_acessibilidade_lote(NULL, 5)  -- 5km radius padrão
  WHERE percentual_cobertura IS NOT NULL;

  -- Índices para performance
  CREATE UNIQUE INDEX idx_metricas_acessibilidade_codigo 
  ON analytics.metricas_acessibilidade_municipios(codigo_ibge);

  CREATE INDEX idx_metricas_acessibilidade_cobertura 
  ON analytics.metricas_acessibilidade_municipios(percentual_cobertura);

  CREATE INDEX idx_metricas_acessibilidade_categoria 
  ON analytics.metricas_acessibilidade_municipios(categoria_cobertura);

  CREATE INDEX idx_metricas_acessibilidade_densidade 
  ON analytics.metricas_acessibilidade_municipios(densidade_escolas_km2);

  -- Função para refresh concorrente
  CREATE OR REPLACE FUNCTION analytics.refresh_metricas_acessibilidade()
  RETURNS VOID AS $$
  BEGIN
      REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.metricas_acessibilidade_municipios;
  END;
  $$ LANGUAGE plpgsql;

  -- View para estatísticas agregadas
  CREATE VIEW analytics.estatisticas_acessibilidade AS
  SELECT 
      COUNT(*) as total_municipios,
      AVG(percentual_cobertura) as cobertura_media,
      MIN(percentual_cobertura) as cobertura_minima,
      MAX(percentual_cobertura) as cobertura_maxima,
      AVG(densidade_escolas_km2) as densidade_media,
      COUNT(*) FILTER (WHERE percentual_cobertura >= 75) as municipios_alta_cobertura,
      COUNT(*) FILTER (WHERE percentual_cobertura < 50) as municipios_baixa_cobertura,
      COUNT(*) FILTER (WHERE n_escolas = 0) as municipios_sem_escolas
  FROM analytics.metricas_acessibilidade_municipios;

  -- Comentários
  COMMENT ON MATERIALIZED VIEW analytics.metricas_acessibilidade_municipios IS 
  'View materializada com métricas de acessibilidade escolar por município (raio 5km)';

  COMMENT ON FUNCTION analytics.refresh_metricas_acessibilidade IS 
  'Atualiza a view materializada de métricas de acessibilidade de forma concorrente';

COMMIT;
