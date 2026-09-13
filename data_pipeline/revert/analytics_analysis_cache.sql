-- Revert edumaps:analytics_analysis_cache from pg
-- requires: schemas

BEGIN;

  DROP TABLE IF EXISTS analytics.analysis_cache;

COMMIT;