-- Revert edumaps:raw_escolas from pg

BEGIN;

  -- Remover tabelas limpas
  DROP TABLE IF EXISTS clean.escolas;

  -- Remover tabelas raw
  DROP TABLE IF EXISTS raw.escolas_raw;

COMMIT;
