-- Verify edumaps:quarantine_censo_escolas_scores on pg
--
-- DO/RAISE EXCEPTION (issue #160).

BEGIN;

DO $$
DECLARE
  c TEXT;
BEGIN
  c := obj_description('clean.censo_escolas_scores'::regclass, 'pg_class');
  IF c IS NULL OR position('DEPRECATED' IN c) = 0 OR position('#137' IN c) = 0 THEN
    RAISE EXCEPTION 'quarantine_censo_escolas_scores: censo_escolas_scores sem a marca de DEPRECATED: %', c;
  END IF;

  c := obj_description('clean.mv_escolas_scores'::regclass, 'pg_class');
  IF c IS NULL OR position('#137' IN c) = 0 THEN
    RAISE EXCEPTION 'quarantine_censo_escolas_scores: mv_escolas_scores sem a declaração canônica (#137): %', c;
  END IF;
END $$;

ROLLBACK;
