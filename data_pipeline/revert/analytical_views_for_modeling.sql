-- Revert edumaps:analytical_views_for_modeling from pg

BEGIN;

  DROP VIEW IF EXISTS analytics.view_escolas_ml;
  DROP VIEW IF EXISTS analytics.view_escolas_ml_spatial;

COMMIT;
