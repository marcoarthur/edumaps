-- Revert edumaps:censo_docentes from pg

BEGIN;

  DROP TABLE IF EXISTS clean.censo_docentes;

COMMIT;
