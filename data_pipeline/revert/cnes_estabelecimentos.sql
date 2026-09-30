-- Revert edumaps:cnes_estabelecimentos from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.cnes_estabelecimentos';

-- Dropar tabela
DROP TABLE IF EXISTS clean.cnes_estabelecimentos;

COMMIT;