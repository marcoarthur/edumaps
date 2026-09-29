-- Revert edumaps:osm_generalize from pg

BEGIN;

DROP TABLE IF EXISTS clean.municipio_osm_feature;
DROP TABLE IF EXISTS clean.school_osm_feature;
DROP TABLE IF EXISTS clean.osm_query_feature;
DROP TABLE IF EXISTS clean.osm_feature;

COMMIT;
