-- Revert edumaps:schemas from pg

BEGIN;
  DROP SCHEMA IF EXISTS analytics CASCADE;
  DROP SCHEMA IF EXISTS clean CASCADE;
  DROP SCHEMA IF EXISTS raw CASCADE;
  DROP SCHEMA IF EXISTS contrib CASCADE;
  DROP SCHEMA IF EXISTS postgis CASCADE;

  DO $$ 
  BEGIN
      EXECUTE format('ALTER DATABASE %I RESET search_path', current_database());
  END $$;

COMMIT;
