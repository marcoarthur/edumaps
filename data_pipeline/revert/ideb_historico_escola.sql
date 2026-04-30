-- Revert edumaps:ideb_historico_escola from pg

BEGIN;

  DROP FUNCTION IF EXISTS clean.ideb_historico_escola(BIGINT);

COMMIT;
