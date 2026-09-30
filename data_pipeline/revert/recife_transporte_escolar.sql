-- Revert edumaps:recife_transporte_escolar from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.recife_transporte_escolar';

-- Dropar tabela
DROP TABLE IF EXISTS clean.recife_transporte_escolar;

COMMIT;