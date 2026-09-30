-- Revert edumaps:antt_contagem_equipamento from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.antt_contagem_equipamento';

-- Dropar tabela
DROP TABLE IF EXISTS clean.antt_contagem_equipamento;

COMMIT;