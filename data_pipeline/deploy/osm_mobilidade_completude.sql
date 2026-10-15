-- requires: censo_labels_consumers
BEGIN;

-- Indicador de qualidade do dado: completude da malha viária no buffer de
-- 500 m da escola. Densidade de metros de via (highway=*) dentro do buffer,
-- normalizada por km² (m/km²).
--
--   NULL  -> sem extração para esta escola/digest (não há o que afirmar)
--   0     -> extração feita, sem via nenhuma no buffer (OSM escasso, viés alto)
--   > 0   -> densidade de metros de via por km²
--
-- É indicador de QUALIDADE do dado, não de mobilidade: torna o viés de
-- cobertura do OSM auditável e comparável entre municípios (#131 e2).
CREATE OR REPLACE FUNCTION clean.iv_mobilidade_completude_malha(
  p_co_entidade   BIGINT,
  p_nu_ano_censo  INTEGER,
  p_digest        TEXT
)
RETURNS FLOAT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_school_geom GEOGRAPHY;
BEGIN
  -- NULL se não há extração para esta escola com este digest
  IF NOT EXISTS (
    SELECT 1 FROM clean.school_osm_feature
    WHERE co_entidade = p_co_entidade
      AND nu_ano_censo = p_nu_ano_censo
      AND digest = p_digest
  ) THEN
    RETURN NULL;
  END IF;

  -- NULL se escola sem geometria
  SELECT geometry::geography INTO v_school_geom
  FROM clean.censo_escolas
  WHERE co_entidade = p_co_entidade
    AND nu_ano_censo = p_nu_ano_censo;

  IF v_school_geom IS NULL THEN
    RETURN NULL;
  END IF;

  -- Densidade de metros de via no buffer de 500 m (m/km²).
  -- A interseção com o buffer conta só a parte da via dentro dos 500 m.
  RETURN COALESCE(
    (
      SELECT
        SUM(
          ST_Length(
            ST_Intersection(
              f.geom::geography,
              ST_Buffer(v_school_geom, 500)
            )::geography
          )
        ) / (pi() * 500^2) * 1e6
      FROM clean.school_osm_feature sof
      JOIN clean.osm_feature f
        ON f.osm_type = sof.osm_type
       AND f.osm_id = sof.osm_id
      WHERE sof.co_entidade = p_co_entidade
        AND sof.nu_ano_censo = p_nu_ano_censo
        AND sof.digest = p_digest
        AND f.tags_key = 'highway'
        AND f.geom IS NOT NULL
    ),
    0
  );
END;
$$;

COMMENT ON FUNCTION clean.iv_mobilidade_completude_malha(BIGINT, INTEGER, TEXT) IS
  'Completude da malha viária no buffer de 500 m da escola (m/km²). '
  'NULL = sem extração; 0 = sem via no buffer; > 0 = densidade de metros de via. '
  'Indicador de qualidade do dado (#131 e2).';

COMMIT;
