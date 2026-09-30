-- Revert edumaps:mapbiomas_cobertura from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.mapbiomas_cobertura';

-- Dropar tabela
DROP TABLE IF EXISTS clean.mapbiomas_cobertura;

COMMIT;