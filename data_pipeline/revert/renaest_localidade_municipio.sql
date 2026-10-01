-- Revert edumaps:renaest_localidade_municipio from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.renaest_localidade_municipio';

-- Dropar tabela
DROP TABLE IF EXISTS clean.renaest_localidade_municipio;

COMMIT;