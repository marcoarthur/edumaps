-- Revert edumaps:antt_trecho_geodados from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.antt_trecho_geodados';

-- Dropar unique constraint
ALTER TABLE clean.antt_trecho_geodados
  DROP CONSTRAINT IF EXISTS uq_antt_trecho_geodados_trecho;

-- Dropar tabela
DROP TABLE IF EXISTS clean.antt_trecho_geodados;

COMMIT;