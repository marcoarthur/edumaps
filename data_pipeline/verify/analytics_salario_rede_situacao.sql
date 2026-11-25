-- Verify edumaps:analytics_salario_rede_situacao on pg
-- #160: o verify precisa dar erro; matview se confere por pg_attribute.

BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM pg_attribute
       WHERE attrelid = 'analytics.mv_salario_rede_md'::regclass AND NOT attisdropped
         AND attname IN ('situacao', 'carga', 'base')) <> 3 THEN
    RAISE EXCEPTION 'mv_salario_rede_md sem situação, carga e base (#597)';
  END IF;
  IF (SELECT count(*) FROM pg_attribute
       WHERE attrelid = 'analytics.mv_salario_rede_md'::regclass AND NOT attisdropped
         AND attname IN ('cpf', 'nome_profissional')) <> 0 THEN
    RAISE EXCEPTION 'mv_salario_rede_md não pode ter CPF nem nome';
  END IF;
END $$;

ROLLBACK;
