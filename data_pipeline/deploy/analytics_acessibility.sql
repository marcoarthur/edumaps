-- Deploy edumaps:analytics_acessibility to pg
-- requires: raw_escolas
-- requires: raw_municipios_sp


BEGIN;

  -- Função para análise de acessibilidade escolar (CORRIGIDA - TIPOS)
  CREATE OR REPLACE FUNCTION analytics.calcular_acessibilidade_municipio(
      p_codigo_ibge VARCHAR(7),
      p_raio_km NUMERIC DEFAULT 5
  )
  RETURNS TABLE (
      percentual_cobertura DOUBLE PRECISION,
      area_coberta_km2 DOUBLE PRECISION,
      area_total_km2 DOUBLE PRECISION,
      n_escolas BIGINT,
      municipio_nome VARCHAR(250),
      codigo_ibge_municipio VARCHAR(7)
  ) 
  LANGUAGE plpgsql
  AS $$
  DECLARE
      v_municipio_geom GEOMETRY;
      v_area_total DOUBLE PRECISION;
      v_area_coberta DOUBLE PRECISION;
      v_n_escolas BIGINT;
      v_municipio_nome VARCHAR(250);
  BEGIN
      -- Validar código IBGE
      IF LENGTH(p_codigo_ibge) != 7 THEN
          RAISE EXCEPTION 'Código IBGE deve ter 7 dígitos';
      END IF;

      -- Obter geometria do município
      SELECT geometry, nome, area_km2
      INTO v_municipio_geom, v_municipio_nome, area_total_km2
      FROM clean.municipios_sp 
      WHERE codigo_ibge = p_codigo_ibge;

      IF v_municipio_geom IS NULL THEN
          RAISE EXCEPTION 'Município com código IBGE % não encontrado', p_codigo_ibge;
      END IF;

      -- Calcular área total (se não estiver no campo area_km2)
      IF area_total_km2 IS NULL OR area_total_km2 = 0 THEN
          area_total_km2 := (ST_Area(v_municipio_geom::GEOGRAPHY) / 1000000);
      END IF;

      -- Obter escolas dentro do município e calcular cobertura
      WITH escolas_no_municipio AS (
          SELECT 
              e.geometry as escola_geom,
              ST_Buffer(e.geometry::GEOGRAPHY, p_raio_km * 1000)::GEOMETRY as buffer_geom
          FROM clean.escolas e
          INNER JOIN clean.municipios_sp m ON ST_Within(e.geometry, m.geometry)
          WHERE m.codigo_ibge = p_codigo_ibge
      ),
      contagem_escolas AS (
          SELECT COUNT(*) as total_escolas
          FROM escolas_no_municipio
      ),
      buffers_agregados AS (
          SELECT ST_Union(buffer_geom) as buffer_unido
          FROM escolas_no_municipio
      ),
      area_coberta_calc AS (
          SELECT 
              CASE 
                  WHEN bu.buffer_unido IS NOT NULL THEN 
                      (ST_Area(ST_Intersection(v_municipio_geom, bu.buffer_unido)::GEOGRAPHY))
                  ELSE 0 
              END as area_coberta
          FROM buffers_agregados bu
      )
      SELECT 
          ce.total_escolas,
          ac.area_coberta
      INTO 
          v_n_escolas,
          v_area_coberta
      FROM contagem_escolas ce, area_coberta_calc ac;

      -- Se não encontrou escolas, retornar zeros
      IF v_n_escolas = 0 OR v_area_coberta IS NULL THEN
          percentual_cobertura := 0;
          area_coberta_km2 := 0;
          n_escolas := 0;
          municipio_nome := v_municipio_nome;
          codigo_ibge_municipio := p_codigo_ibge;
          RETURN NEXT;
          RETURN;
      END IF;

      -- Calcular métricas finais
      area_coberta_km2 := v_area_coberta / 1000000;
      percentual_cobertura := (area_coberta_km2 / area_total_km2) * 100;
      n_escolas := v_n_escolas;
      municipio_nome := v_municipio_nome;
      codigo_ibge_municipio := p_codigo_ibge;

      RETURN NEXT;
  END;
  $$;

  CREATE OR REPLACE FUNCTION analytics.calcular_acessibilidade_lote(
      p_codigos_ibge VARCHAR(7)[] DEFAULT NULL,
      p_raio_km NUMERIC DEFAULT 5
  )
  RETURNS TABLE (
      percentual_cobertura DOUBLE PRECISION,
      area_coberta_km2 DOUBLE PRECISION,
      area_total_km2 DOUBLE PRECISION,
      n_escolas BIGINT,
      municipio_nome VARCHAR(250),
      codigo_ibge_municipio VARCHAR(7)
  ) 
  LANGUAGE plpgsql
  AS $$
  BEGIN
      RETURN QUERY
      WITH municipios_alvo AS (
          SELECT 
              m.codigo_ibge,
              m.nome,
              m.area_km2,
              m.geometry,
              CASE 
                  WHEN m.area_km2 IS NULL OR m.area_km2 = 0 
                  THEN (ST_Area(m.geometry::GEOGRAPHY) / 1000000)
                  ELSE m.area_km2 
              END as area_total_calculada
          FROM clean.municipios_sp m
          WHERE p_codigos_ibge IS NULL OR m.codigo_ibge = ANY(p_codigos_ibge)
      ),
      escolas_com_buffer AS (
          SELECT 
              m.codigo_ibge,
              e.geometry as escola_geom,
              ST_Buffer(e.geometry::GEOGRAPHY, p_raio_km * 1000)::GEOMETRY as buffer_geom
          FROM municipios_alvo m
          INNER JOIN clean.escolas e ON ST_Within(e.geometry, m.geometry)
      ),
      escolas_por_municipio AS (
          SELECT 
              codigo_ibge,
              COUNT(*) as n_escolas
          FROM escolas_com_buffer
          GROUP BY codigo_ibge
      ),
      buffers_por_municipio AS (
          SELECT 
              codigo_ibge,
              ST_Union(buffer_geom) as buffer_unido
          FROM escolas_com_buffer
          GROUP BY codigo_ibge
      ),
      cobertura_por_municipio AS (
          SELECT 
              b.codigo_ibge,
              (ST_Area(ST_Intersection(m.geometry, b.buffer_unido)::GEOGRAPHY)) as area_coberta_m2
          FROM buffers_por_municipio b
          INNER JOIN municipios_alvo m ON b.codigo_ibge = m.codigo_ibge
          WHERE b.buffer_unido IS NOT NULL
      )
      SELECT 
          (CASE 
              WHEN c.area_coberta_m2 IS NULL THEN 0
              ELSE (c.area_coberta_m2 / 1000000 / m.area_total_calculada) * 100 
          END) as percentual_cobertura,
          (COALESCE(c.area_coberta_m2 / 1000000, 0)) as area_coberta_km2,
          m.area_total_calculada as area_total_km2,
          COALESCE(e.n_escolas, 0) as n_escolas,
          m.nome as municipio_nome,
          m.codigo_ibge as codigo_ibge_municipio
      FROM municipios_alvo m
      LEFT JOIN escolas_por_municipio e ON m.codigo_ibge = e.codigo_ibge
      LEFT JOIN cobertura_por_municipio c ON m.codigo_ibge = c.codigo_ibge
      ORDER BY percentual_cobertura DESC NULLS LAST;
  END;
  $$;

  -- Comentários das funções
  COMMENT ON FUNCTION analytics.calcular_acessibilidade_municipio IS 'Calcula métricas de acessibilidade escolar para um município específico';
  COMMENT ON FUNCTION analytics.calcular_acessibilidade_lote IS 'Calcula métricas de acessibilidade escolar para múltiplos municípios em lote';

COMMIT;
