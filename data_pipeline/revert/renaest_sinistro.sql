-- Revert edumaps:renaest_sinistro from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.renaest_sinistro';

-- Dropar tabela
DROP TABLE IF EXISTS clean.renaest_sinistro;

COMMIT;