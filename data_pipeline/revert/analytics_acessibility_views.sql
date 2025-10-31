-- Revert edumaps:analytics_acessibility_views from pg

BEGIN;

  DROP FUNCTION IF EXISTS analytics.calcular_acessibilidade_filtrada;
  DROP VIEW IF EXISTS analytics.escolas_filtradas;
  DROP VIEW IF EXISTS analytics.estatisticas_acessibilidade;
  DROP FUNCTION IF EXISTS analytics.refresh_metricas_acessibilidade;
  DROP MATERIALIZED VIEW IF EXISTS analytics.metricas_acessibilidade_municipios;

COMMIT;
