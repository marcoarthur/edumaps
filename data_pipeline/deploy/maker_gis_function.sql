-- Deploy edumaps:maker_gis_function to pg

BEGIN;

  CREATE OR REPLACE FUNCTION clean.get_cities_markers(
      p_bbox text,  -- formato: "min_lng,min_lat,max_lng,max_lat"
      p_zoom integer,
      p_limit integer DEFAULT 150
  )
  RETURNS JSON AS $$
  DECLARE
      result JSON;
      min_lng NUMERIC;
      min_lat NUMERIC;
      max_lng NUMERIC;
      max_lat NUMERIC;
  BEGIN
      -- Parse da bounding box
      min_lng := split_part(p_bbox, ',', 1)::NUMERIC;
      min_lat := split_part(p_bbox, ',', 2)::NUMERIC;
      max_lng := split_part(p_bbox, ',', 3)::NUMERIC;
      max_lat := split_part(p_bbox, ',', 4)::NUMERIC;
      
      SELECT json_agg(
          json_build_object(
              'codigo_ibge', mv.co_municipio,
              'nome_municipio', mv.no_municipio,
              'sigla_estado', mv.sg_uf,
              'latitude', ST_Y(ST_Centroid(m.geometry)),
              'longitude', ST_X(ST_Centroid(m.geometry)),
              'populacao_estimada', mv.populacao_estimada,
              'analise', json_build_object(
                  'ideb_fund_ii', mv.ideb_fund_ii,
                  'total_escolas', mv.total_escolas,
                  'total_alunos', mv.total_alunos,
                  'pib_per_capita', mv.pib_per_capita
              )
          )
          ORDER BY mv.populacao_estimada DESC
      ) INTO result
      FROM analytics.mv_municipios_consolidado mv
      JOIN clean.municipios_sp m ON m.codigo_ibge = mv.co_municipio::text
      WHERE ST_Intersects(
          m.geometry,  -- SRID 4674
          ST_Transform(  -- ← Converter envelope para SRID 4674
              ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326),
              4674
          )
      )
      LIMIT p_limit;
      
      RETURN COALESCE(result, '[]'::JSON);
  END;
  $$ LANGUAGE plpgsql;

COMMIT;
