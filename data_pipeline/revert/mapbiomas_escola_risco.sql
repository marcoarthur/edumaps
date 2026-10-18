-- Revert edumaps:mapbiomas_escola_risco from pg

BEGIN;

DROP TABLE IF EXISTS clean.mapbiomas_escola_risco;

DELETE FROM clean.import_metadata WHERE table_name = 'clean.mapbiomas_escola_risco';

COMMIT;
