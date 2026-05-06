-- Revert edumaps:analytics_municipios_consolidado from pg

BEGIN;

  DROP FUNCTION IF EXISTS analytics.refresh_municipios_consolidado();
  DROP MATERIALIZED VIEW IF EXISTS analytics.mv_municipios_consolidado;

COMMIT;
