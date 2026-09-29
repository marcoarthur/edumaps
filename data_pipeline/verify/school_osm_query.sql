-- Verify edumaps:school_osm_query on pg
-- requires: osm_generalize

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.school_osm_query') IS NULL THEN
    RAISE EXCEPTION 'tabela clean.school_osm_query ausente';
  END IF;
END $$;

ROLLBACK;
