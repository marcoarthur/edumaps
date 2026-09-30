-- Revert edumaps:siconfi_despesa from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.siconfi_despesa';

-- Dropar tabela
DROP TABLE IF EXISTS clean.siconfi_despesa;

COMMIT;