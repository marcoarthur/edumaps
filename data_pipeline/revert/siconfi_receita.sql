-- Revert edumaps:siconfi_receita from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.siconfi_receita';

-- Dropar tabela
DROP TABLE IF EXISTS clean.siconfi_receita;

COMMIT;