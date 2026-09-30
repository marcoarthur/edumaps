-- Revert edumaps:antt_acidente_trecho from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.antt_acidente_trecho';

-- Dropar tabela
DROP TABLE IF EXISTS clean.antt_acidente_trecho;

COMMIT;