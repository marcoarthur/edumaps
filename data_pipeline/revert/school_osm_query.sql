-- Revert edumaps:school_osm_query from pg

BEGIN;

DROP TABLE IF EXISTS clean.school_osm_query;

COMMIT;
