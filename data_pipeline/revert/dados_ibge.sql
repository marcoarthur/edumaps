-- Revert edumaps:dados_ibge from pg

BEGIN;

  DROP TABLE IF EXISTS clean.dados_ibge;

COMMIT;
