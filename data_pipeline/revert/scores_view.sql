-- Revert edumaps:scores_view from pg

BEGIN;

  -- Remove a view se ela existir (sem erro caso não exista)
  DROP VIEW IF EXISTS clean.censo_escolas_scores CASCADE;

COMMIT;
