-- Verify edumaps:analytics_salario_rede on pg
-- #160: o verify precisa dar erro; matview se confere por pg_attribute.

BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM pg_matviews
       WHERE schemaname = 'analytics' AND matviewname IN ('mv_salario_rede', 'mv_salario_rede_md')) <> 2 THEN
    RAISE EXCEPTION 'faltam as matviews do salário da rede (#595)';
  END IF;
  IF (SELECT count(*) FROM pg_attribute
       WHERE attrelid = 'analytics.mv_salario_rede_md'::regclass AND NOT attisdropped
         AND attname IN ('cpf', 'nome_profissional')) <> 0 THEN
    RAISE EXCEPTION 'mv_salario_rede_md não pode ter CPF nem nome';
  END IF;
  IF to_regprocedure('analytics.refresh_salario_rede()') IS NULL THEN
    RAISE EXCEPTION 'falta analytics.refresh_salario_rede()';
  END IF;
END $$;

ROLLBACK;
