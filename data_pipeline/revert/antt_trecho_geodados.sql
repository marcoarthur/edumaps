-- Revert edumaps:antt_trecho_geodados from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.antt_trecho_geodados';

-- Dropar tabela
DROP TABLE IF EXISTS clean.antt_trecho_geodados;

COMMIT;