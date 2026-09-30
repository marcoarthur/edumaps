-- Revert edumaps:inmet_alerta from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.inmet_alerta';

-- Dropar tabela
DROP TABLE IF EXISTS clean.inmet_alerta;

COMMIT;