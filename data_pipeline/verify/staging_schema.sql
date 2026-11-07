-- Verify edumaps:staging_schema on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regnamespace('staging') IS NULL THEN
    RAISE EXCEPTION 'schema staging ausente';
  END IF;
END
$$;

ROLLBACK;
