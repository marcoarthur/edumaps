-- Revert edumaps:censo_escolar_2025 from pg

BEGIN;

  DROP TABLE IF EXISTS clean.censo_escolas CASCADE;

COMMIT;
