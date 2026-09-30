-- Revert edumaps:isocrona_escolar from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.isocrona_escolar';

-- Dropar tabela
DROP TABLE IF EXISTS clean.isocrona_escolar;

COMMIT;