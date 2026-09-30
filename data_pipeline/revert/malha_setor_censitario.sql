-- Revert edumaps:malha_setor_censitario from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.malha_setor_censitario';

-- Dropar tabela
DROP TABLE IF EXISTS clean.malha_setor_censitario;

COMMIT;