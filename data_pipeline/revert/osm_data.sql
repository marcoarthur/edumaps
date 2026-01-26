-- Revert edumaps:osm_data from pg

BEGIN;

  DROP TABLE IF EXISTS clean.osm_landuse;
  DROP TABLE IF EXISTS clean.osm_query;

COMMIT;
