-- Revert edumaps:analytics_municipios_similaridade from pg

BEGIN;

  -- Drop índices
  DROP INDEX IF EXISTS analytics.idx_municipio_similaridade_m1_sim;
  DROP INDEX IF EXISTS analytics.idx_municipio_similaridade_sim;
  DROP INDEX IF EXISTS analytics.idx_municipio_similaridade_pair;
  
  -- Drop a materialized view
  DROP MATERIALIZED VIEW IF EXISTS analytics.municipio_similaridade;

COMMIT;
