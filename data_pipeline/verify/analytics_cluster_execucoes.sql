-- Verify edumaps:analytics_cluster_execucoes on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('analytics.cluster_execucoes') IS NULL THEN
    RAISE EXCEPTION 'analytics_cluster_execucoes: falta analytics.cluster_execucoes';
  END IF;
  IF to_regclass('analytics.cluster_atribuicoes') IS NULL THEN
    RAISE EXCEPTION 'analytics_cluster_execucoes: falta analytics.cluster_atribuicoes';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'analytics.cluster_atribuicoes'::regclass AND contype = 'f') THEN
    RAISE EXCEPTION 'analytics_cluster_execucoes: falta a FK das atribuições para a execução';
  END IF;
END
$$;

ROLLBACK;
