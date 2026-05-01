-- Verify edumaps:badge_functions on pg

BEGIN;
  -- Helper: raise exception if function does not exist in clean schema
  DO $$
  DECLARE
      func_oid oid;
  BEGIN
      -- 1. infra_badge_bag
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'infra_badge_bag'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.infra_badge_bag does not exist';
      END IF;
      IF pg_get_function_result(func_oid)::text <> 'json' THEN
          RAISE EXCEPTION 'clean.infra_badge_bag does not return json';
      END IF;

      -- 2. accessibility_badge_bag
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'accessibility_badge_bag'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.accessibility_badge_bag does not exist';
      END IF;
      IF pg_get_function_result(func_oid)::text <> 'json' THEN
          RAISE EXCEPTION 'clean.accessibility_badge_bag does not return json';
      END IF;

      -- 3. internet_badge_bag
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'internet_badge_bag'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.internet_badge_bag does not exist';
      END IF;
      IF pg_get_function_result(func_oid)::text <> 'json' THEN
          RAISE EXCEPTION 'clean.internet_badge_bag does not return json';
      END IF;

      -- 4. typification_badge
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'typification_badge'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.typification_badge does not exist';
      END IF;
      IF pg_get_function_result(func_oid)::text <> 'json' THEN
          RAISE EXCEPTION 'clean.typification_badge does not return json';
      END IF;

      -- 5. quick_score_avaliation
      SELECT oid INTO func_oid FROM pg_proc
      WHERE proname = 'quick_score_avaliation'
        AND pronamespace = 'clean'::regnamespace;
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Function clean.quick_score_avaliation does not exist';
      END IF;
      IF pg_get_function_result(func_oid)::text <> 'json' THEN
          RAISE EXCEPTION 'clean.quick_score_avaliation does not return json';
      END IF;
  END $$;

  -- Optional: smoke test with an invalid school ID
  -- (must return empty array/object, not error)
  DO $$
  BEGIN
      PERFORM clean.infra_badge_bag(-1);
      PERFORM clean.accessibility_badge_bag(-1);
      PERFORM clean.internet_badge_bag(-1);
      PERFORM clean.typification_badge(-1);
      PERFORM clean.quick_score_avaliation(-1);
  EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Smoke test failed: %', SQLERRM;
  END $$;
COMMIT;
