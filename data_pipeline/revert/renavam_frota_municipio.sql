-- Revert edumaps:renavam_frota_municipio from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.renavam_frota_municipio';

-- Dropar tabela
DROP TABLE IF EXISTS clean.renavam_frota_municipio;

COMMIT;