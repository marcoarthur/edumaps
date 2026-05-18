-- Revert edumaps:nro_etapas from pg

BEGIN;

  ALTER TABLE clean.censo_escolas DROP COLUMN nro_etapas;

COMMIT;
