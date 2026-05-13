-- Revert edumaps:consistent_schools_mv from pg

BEGIN;

  DROP MATERIALIZED VIEW IF EXISTS consistent_schools;

COMMIT;
