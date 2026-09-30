-- Revert edumaps:censo2022_setor from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.censo2022_setor';

-- Dropar tabela
DROP TABLE IF EXISTS clean.censo2022_setor;

COMMIT;