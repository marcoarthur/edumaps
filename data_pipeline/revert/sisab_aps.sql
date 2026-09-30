-- Revert edumaps:sisab_aps from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.sisab_aps';

-- Dropar tabela
DROP TABLE IF EXISTS clean.sisab_aps;

COMMIT;