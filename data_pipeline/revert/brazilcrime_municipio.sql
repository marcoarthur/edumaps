-- Revert edumaps:brazilcrime_municipio from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.brazilcrime_municipio';

-- Dropar tabela
DROP TABLE IF EXISTS clean.brazilcrime_municipio;

COMMIT;