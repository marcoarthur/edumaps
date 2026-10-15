-- Revert edumaps:escola_influencia from pg

BEGIN;

DROP FUNCTION IF EXISTS clean.refresh_escola_influencia(integer[], bigint[]);
DROP TABLE IF EXISTS clean.escola_influencia;

COMMIT;
