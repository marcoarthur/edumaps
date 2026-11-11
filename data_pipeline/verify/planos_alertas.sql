-- Verify edumaps:planos_alertas on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.planos_alertas_envio') IS NULL THEN
    RAISE EXCEPTION 'planos_alertas: falta clean.planos_alertas_envio';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_planos_alertas_gestor_dia') THEN
    RAISE EXCEPTION 'planos_alertas: falta a unicidade gestor/dia (idempotência do resumo)';
  END IF;
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
     AND has_table_privilege('edumaps_leitor', 'clean.planos_alertas_envio', 'SELECT') THEN
    RAISE EXCEPTION 'planos_alertas: edumaps_leitor não pode ler clean.planos_alertas_envio';
  END IF;
END
$$;

ROLLBACK;
