-- Revert edumaps:antt_od_municipio from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.antt_od_municipio';

-- Dropar tabela
DROP TABLE IF EXISTS clean.antt_od_municipio;

COMMIT;