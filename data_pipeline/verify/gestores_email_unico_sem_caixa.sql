-- Verify edumaps:gestores_email_unico_sem_caixa on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro; ver
-- verify/analytics_ausencia_visivel.sql)

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
     WHERE schemaname = 'clean' AND indexname = 'uq_gestores_email_lower'
       AND indexdef ILIKE '%UNIQUE%lower(email)%'
  ) THEN
    RAISE EXCEPTION 'falta o índice único clean.uq_gestores_email_lower em lower(email)';
  END IF;
END
$$;

ROLLBACK;
