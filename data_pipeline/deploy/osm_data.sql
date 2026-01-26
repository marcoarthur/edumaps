-- Deploy edumaps:osm_data to pg
-- requires: raw_municipios_sp

BEGIN;
  DROP TABLE IF EXISTS clean.osm_query;
  CREATE TABLE IF NOT EXISTS clean.osm_query(
    digest          TEXT PRIMARY KEY,
    query           TEXT NOT NULL,
    last_run        TIMESTAMP DEFAULT NOW(),
    elapsed_time    FLOAT,
    raw_results     JSON DEFAULT NULL,
    city_fid        VARCHAR(7) NOT NULL
  );

  DROP TABLE IF EXISTS clean.osm_landuse;
  CREATE TABLE IF NOT EXISTS clean.osm_landuse
  (
    osm_id            BIGINT PRIMARY KEY,
    municipio_id      VARCHAR(7) REFERENCES clean.municipios_sp(codigo_ibge),
    osm_query_id      TEXT    REFERENCES clean.osm_query(digest),
    geom              GEOMETRY(GEOMETRY, 4674),
    properties        JSONB,
    land_use          TEXT
  );

COMMIT;
