-- Revert edumaps:raw_siope from pg

BEGIN;

  DROP TABLE IF EXISTS clean.remuneracao_municipal;
  DROP TABLE IF EXISTS raw.remuneracao_siope_raw;

COMMIT;
