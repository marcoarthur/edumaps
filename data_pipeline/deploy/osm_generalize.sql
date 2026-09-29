-- Deploy edumaps:osm_generalize to pg
-- requires: osm_data
--
-- Generaliza o cache OSM para além de "landuse" (way-only):
--   * clean.osm_feature          - features de qualquer tipo (node/way/relation)
--                                  com chave composta (osm_type, osm_id)
--   * clean.osm_query_feature    - proveniência (query -> feature)
--   * clean.school_osm_feature   - relação escola (buffer) -> feature
--   * clean.municipio_osm_feature- relação município (polígono) -> feature
--
-- clean.osm_landuse permanece (legado) e seus dados são migrados para
-- clean.osm_feature como osm_type = 'way'.

BEGIN;

CREATE TABLE IF NOT EXISTS clean.osm_feature (
  osm_type    TEXT NOT NULL,
  osm_id      BIGINT NOT NULL,
  tags_key    TEXT,
  tags_value  TEXT,
  category    TEXT,
  geom        GEOMETRY(GEOMETRY, 4674),
  properties  JSONB,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (osm_type, osm_id)
);

CREATE INDEX IF NOT EXISTS osm_feature_geom_gix
  ON clean.osm_feature USING gist (geom);
CREATE INDEX IF NOT EXISTS osm_feature_category_ix
  ON clean.osm_feature (tags_key, tags_value);

CREATE TABLE IF NOT EXISTS clean.osm_query_feature (
  digest   TEXT NOT NULL REFERENCES clean.osm_query(digest) ON DELETE CASCADE,
  osm_type TEXT NOT NULL,
  osm_id   BIGINT NOT NULL,
  PRIMARY KEY (digest, osm_type, osm_id)
);

CREATE TABLE IF NOT EXISTS clean.school_osm_feature (
  co_entidade  BIGINT NOT NULL,
  nu_ano_censo INTEGER NOT NULL,
  osm_type     TEXT NOT NULL,
  osm_id       BIGINT NOT NULL,
  raio         INTEGER NOT NULL,
  distance_m   DOUBLE PRECISION,
  digest       TEXT REFERENCES clean.osm_query(digest),
  created_at   TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (co_entidade, nu_ano_censo, osm_type, osm_id)
);

CREATE INDEX IF NOT EXISTS school_osm_feature_osm_ix
  ON clean.school_osm_feature (osm_type, osm_id);

CREATE TABLE IF NOT EXISTS clean.municipio_osm_feature (
  codigo_ibge VARCHAR(7) NOT NULL REFERENCES clean.municipios_sp(codigo_ibge),
  osm_type    TEXT NOT NULL,
  osm_id      BIGINT NOT NULL,
  digest      TEXT REFERENCES clean.osm_query(digest),
  created_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (codigo_ibge, osm_type, osm_id)
);

CREATE INDEX IF NOT EXISTS municipio_osm_feature_osm_ix
  ON clean.municipio_osm_feature (osm_type, osm_id);

-- Migra o legado (way) para a tabela generalizada, derivando tags_key/value
-- da primeira chave relevante presente em properties.
INSERT INTO clean.osm_feature (osm_type, osm_id, tags_key, tags_value, category, geom, properties)
SELECT
  'way',
  l.osm_id,
  kv.k,
  l.properties ->> kv.k,
  kv.k || '=' || (l.properties ->> kv.k),
  l.geom,
  l.properties
FROM clean.osm_landuse l
CROSS JOIN LATERAL (
  SELECT k FROM (VALUES ('landuse'), ('natural'), ('leisure'), ('man_made')) AS v(k)
  WHERE l.properties ? k
  LIMIT 1
) kv
WHERE l.geom IS NOT NULL
ON CONFLICT (osm_type, osm_id) DO NOTHING;

COMMIT;
