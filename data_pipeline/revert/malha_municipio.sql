-- Revert edumaps:malha_municipio from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.malha_municipio';

-- Dropar tabela
DROP TABLE IF EXISTS clean.malha_municipio;

-- Dropar servidor FDW
DROP SERVER IF EXISTS fdw_ibge_malha_municipio CASCADE;

COMMIT;