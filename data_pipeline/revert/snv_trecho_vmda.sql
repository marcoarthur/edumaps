-- Revert edumaps:snv_trecho_vmda from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.snv_trecho_vmda';

-- Dropar tabela
DROP TABLE IF EXISTS clean.snv_trecho_vmda;

COMMIT;