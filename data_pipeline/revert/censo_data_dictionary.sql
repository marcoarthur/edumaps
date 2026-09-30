-- Revert edumaps:censo_data_dictionary from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.censo_data_dictionary';

-- Dropar a tabela
DROP TABLE IF EXISTS clean.censo_data_dictionary;

COMMIT;