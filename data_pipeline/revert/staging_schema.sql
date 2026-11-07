-- Revert edumaps:staging_schema from pg
-- Só apaga o schema se estiver vazio: num banco em que ele já existia antes
-- desta change (com tabelas), o revert não destrói nada.

BEGIN;

  DO $$
  BEGIN
    IF to_regnamespace('staging') IS NULL THEN
      RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_class WHERE relnamespace = 'staging'::regnamespace) THEN
      RAISE NOTICE 'schema staging tem objetos; mantido';
      RETURN;
    END IF;
    DROP SCHEMA staging;
  END
  $$;

COMMIT;
