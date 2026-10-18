-- Revert edumaps:mapbiomas_escola from pg

BEGIN;

DROP VIEW IF EXISTS clean.v_mapbiomas_escola_grupos;
DROP TABLE IF EXISTS clean.mapbiomas_escola;

DELETE FROM clean.import_metadata WHERE table_name = 'clean.mapbiomas_escola';

COMMIT;
