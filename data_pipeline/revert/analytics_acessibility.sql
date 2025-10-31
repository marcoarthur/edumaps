-- Revert edumaps:analytics_acessibility from pg

BEGIN;

  DROP FUNCTION IF EXISTS analytics.calcular_acessibilidade_lote;
  DROP FUNCTION IF EXISTS analytics.calcular_acessibilidade_municipio;

COMMIT;
