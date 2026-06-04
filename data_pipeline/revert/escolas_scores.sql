-- Revert edumaps:escolas_scores from pg

BEGIN;

  DROP MATERIALIZED VIEW IF EXISTS clean.mv_escolas_scores;

COMMIT;
