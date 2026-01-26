/* 
DDL for OSM datasets based on cities' geometries
*/

BEGIN;
  DROP TABLE IF EXISTS osm_query;
  CREATE TABLE IF NOT EXISTS osm_query(
    digest          TEXT PRIMARY KEY,
    query           TEXT NOT NULL,
    last_run        TIMESTAMP DEFAULT NOW(),
    elapsed_time    FLOAT,
    raw_results     JSON DEFAULT NULL,
    city_fid        INTEGER NOT NULL
  );

  DROP TABLE IF EXISTS osm_landuse;
  CREATE TABLE IF NOT EXISTS osm_landuse
  (
    osm_id            BIGINT PRIMARY KEY,
    municipio_id      INTEGER REFERENCES municipios_sp(fid),
    osm_query_id      TEXT    REFERENCES osm_query(digest),
    geom              GEOMETRY(GEOMETRY, 4674),
    properties        JSONB,
    land_use          TEXT
  );

  CREATE INDEX idx_osm_landuse_geography_gist ON clean.osm_landuse USING GIST (geography(geom));
  CREATE INDEX idx_osm_landuse_properties_gin ON clean.osm_landuse USING GIN (properties);
COMMIT;
