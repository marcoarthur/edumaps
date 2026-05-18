-- Verify edumaps:health_check on pg

BEGIN;
  -- Helper: raise exception if function does not exist or does not return a set
  DO $$
  DECLARE
      func_oid oid;
      func_record record;
  BEGIN
      -- 1. Check existence of health_check_approx in clean schema
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'health_check_approx'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.health_check_approx does not exist';
      END IF;

      -- 2. Check that it returns a set (TABLE/ SETOF)
      SELECT proretset INTO func_record FROM pg_proc WHERE oid = func_oid;
      IF NOT func_record.proretset THEN
          RAISE EXCEPTION 'clean.health_check_approx does not return a set (TABLE/SETOF)';
      END IF;

  END $$;
ROLLBACK;
