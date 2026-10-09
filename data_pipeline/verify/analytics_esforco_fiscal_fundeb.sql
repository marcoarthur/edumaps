-- Verify edumaps:analytics_esforco_fiscal_fundeb on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION): um SELECT
-- preguiçoso devolve 'f' e o Sqitch 1.6.1 reporta 'ok' (issue #160).

BEGIN;

DO $$
DECLARE
  n_view INTEGER;
  n_bad  INTEGER;
BEGIN
  -- 1) A view existe
  SELECT count(*) INTO n_view
    FROM information_schema.views
   WHERE table_schema = 'analytics'
     AND table_name   = 'esforco_fiscal_educacao';
  IF n_view = 0 THEN
    RAISE EXCEPTION 'analytics_esforco_fiscal_fundeb: analytics.esforco_fiscal_educacao ausente';
  END IF;

  -- 2) Contrato do dado (só morde se houver linhas fora dele)
  SELECT count(*) INTO n_bad
    FROM clean.siconfi_receita
   WHERE tipo_receita NOT IN ('propria', 'transferencia', 'fundeb', 'outros');
  IF n_bad > 0 THEN
    RAISE EXCEPTION 'analytics_esforco_fiscal_fundeb: % linhas com tipo_receita fora do contrato', n_bad;
  END IF;
END $$;

ROLLBACK;