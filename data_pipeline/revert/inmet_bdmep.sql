-- Revert edumaps:inmet_bdmep from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.inmet_bdmep';

-- Dropar tabela
DROP TABLE IF EXISTS clean.inmet_bdmep;

COMMIT;