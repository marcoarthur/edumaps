-- Revert edumaps:analytic_school_model from pg

BEGIN;

  DROP MATERIALIZED VIEW IF EXISTS analytics.escola_features;
  DROP FUNCTION analytics.prepare_school_data(
    p_censo_year INTEGER,
    p_ideb_year INTEGER,
    p_inse_year INTEGER,
    p_etapa TEXT
  );

COMMIT;
