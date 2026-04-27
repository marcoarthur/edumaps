-- Verify edumaps:scores_view on pg

BEGIN;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'clean' AND table_name = 'censo_escolas_scores'
  ) AS view_exists;
ROLLBACK;
