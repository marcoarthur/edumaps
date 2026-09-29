-- Verify edumaps:osm_generalize on pg
-- requires: osm_data
--
-- Falha se alguma das tabelas generalizadas não existir.

BEGIN;

DO $$
DECLARE
  t text;
  missing text := '';
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'osm_feature', 'osm_query_feature',
    'school_osm_feature', 'municipio_osm_feature'
  ] LOOP
    IF to_regclass('clean.' || t) IS NULL THEN
      missing := missing || ' ' || t;
    END IF;
  END LOOP;

  IF missing <> '' THEN
    RAISE EXCEPTION 'tabelas ausentes:%', missing;
  END IF;
END $$;

ROLLBACK;
