-- Revert edumaps:analytics_rede_escolas from pg

BEGIN;

  DROP FUNCTION IF EXISTS analytics.refresh_rede_escolas();
  DROP MATERIALIZED VIEW IF EXISTS analytics.mv_rede_escolas;

COMMIT;