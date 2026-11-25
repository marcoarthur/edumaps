-- Revert edumaps:analytics_salario_rede from pg

BEGIN;

DROP FUNCTION IF EXISTS analytics.refresh_salario_rede();
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_salario_rede_md;
DROP MATERIALIZED VIEW IF EXISTS analytics.mv_salario_rede;

COMMIT;
