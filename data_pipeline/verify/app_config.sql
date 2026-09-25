-- Verify edumaps:app_config from pg
BEGIN;

  DO $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname = 'pgcrypto') THEN
      RAISE EXCEPTION 'extensão pgcrypto ausente';
    END IF;
    IF to_regclass('app_config.items') IS NULL THEN
      RAISE EXCEPTION 'tabela app_config.items ausente';
    END IF;
  END
  $$;

  SELECT CASE WHEN COUNT(*) = 7 THEN TRUE ELSE FALSE END
  FROM information_schema.columns
  WHERE table_schema = 'app_config' AND table_name = 'items'
    AND column_name IN ('key', 'value', 'secret', 'secret_key_version', 'sensitive', 'updated_by', 'updated_at');

ROLLBACK;