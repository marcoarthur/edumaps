-- Revert edumaps:raw_inep from pg

BEGIN;

  -- Reverter na ordem inversa da criação
  DROP TABLE IF EXISTS clean.inep;
  DROP TABLE IF EXISTS raw.inep_raw;
  
  -- Reverter as funções helper
  DROP FUNCTION IF EXISTS clean.to_numeric_safe(TEXT);
  DROP FUNCTION IF EXISTS clean.null_if_invalid(TEXT);

COMMIT;
