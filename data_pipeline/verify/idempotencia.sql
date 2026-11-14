-- Verify edumaps:idempotencia on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.idempotencia') IS NULL THEN
    RAISE EXCEPTION 'idempotencia: falta clean.idempotencia';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'clean.idempotencia'::regclass AND contype = 'p') THEN
    RAISE EXCEPTION 'idempotencia: falta a chave primária (gestor_id, chave)';
  END IF;
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
     AND has_table_privilege('edumaps_leitor', 'clean.idempotencia', 'SELECT') THEN
    RAISE EXCEPTION 'idempotencia: edumaps_leitor não pode ler clean.idempotencia';
  END IF;
END
$$;

ROLLBACK;
