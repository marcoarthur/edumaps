-- Revert edumaps:edumaps_leitor_role from pg
-- requires: schemas

BEGIN;

  ALTER DEFAULT PRIVILEGES IN SCHEMA clean
    REVOKE SELECT ON SEQUENCES FROM edumaps_leitor;
  ALTER DEFAULT PRIVILEGES IN SCHEMA clean
    REVOKE SELECT ON TABLES FROM edumaps_leitor;

  ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
    REVOKE SELECT ON SEQUENCES FROM edumaps_leitor;
  ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
    REVOKE SELECT ON TABLES FROM edumaps_leitor;

  REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA clean, analytics FROM edumaps_leitor;
  REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA clean, analytics FROM edumaps_leitor;
  REVOKE USAGE ON SCHEMA clean, analytics FROM edumaps_leitor;

  DO $$
  BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
      DROP ROLE edumaps_leitor;
    END IF;
  END $$;

COMMIT;