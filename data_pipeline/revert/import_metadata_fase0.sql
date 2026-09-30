-- Revert edumaps:import_metadata_fase0 from pg

BEGIN;

-- Remover índice
DROP INDEX IF EXISTS clean.idx_import_metadata_source_url;

-- Remover colunas
ALTER TABLE clean.import_metadata
    DROP COLUMN IF EXISTS source_url,
    DROP COLUMN IF EXISTS source_license,
    DROP COLUMN IF EXISTS retrieved_at;

COMMIT;