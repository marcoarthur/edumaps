-- Revert edumaps:escola_entorno_socioeconomico from pg
BEGIN;

DROP FUNCTION IF EXISTS clean.refresh_escola_entorno_socioeconomico(integer[], bigint[]);
DROP TABLE IF EXISTS clean.escola_entorno_socioeconomico;

COMMIT;
