-- Revert edumaps:participacoes_exame from pg

BEGIN;

  ALTER TABLE clean.censo_escolas DROP COLUMN IF EXISTS nro_participacoes_exame;

COMMIT;
