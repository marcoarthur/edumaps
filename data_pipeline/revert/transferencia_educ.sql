-- Revert edumaps:transferencia_educ from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.transferencia_educ';

-- Dropar tabela
DROP TABLE IF EXISTS clean.transferencia_educ;

COMMIT;