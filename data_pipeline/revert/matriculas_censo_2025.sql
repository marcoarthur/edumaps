-- Revert edumaps:matriculas_censo_2025 from pg

BEGIN;

  DROP TABLE IF EXISTS clean.censo_matriculas;

COMMIT;
