-- Revert edumaps:ideb_notas_escolas from pg

BEGIN;

  DROP TABLE IF EXISTS clean.ideb_notas_escolas;

COMMIT;
