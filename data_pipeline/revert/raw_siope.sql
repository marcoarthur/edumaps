-- Revert edumaps:raw_siope from pg

BEGIN;

  DROP TABLE IF EXISTS clean.remuneracao_siope;
  DROP TABLE IF EXISTS raw.remuneracao_siope_raw;

  DROP FUNCTION IF EXISTS clean.to_numeric_safe(TEXT);
  DROP FUNCTION IF EXISTS clean.texto_limpo(TEXT);

COMMIT;
