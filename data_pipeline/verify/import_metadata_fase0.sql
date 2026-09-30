-- Verify edumaps:import_metadata_fase0 on pg

BEGIN;

-- 1) Colunas existem
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'import_metadata'
  AND column_name IN ('source_url', 'source_license', 'retrieved_at')
  AND is_nullable = 'YES';

-- 2) Tipos corretos
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'import_metadata'
  AND column_name = 'source_url'
  AND data_type = 'text';

SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'import_metadata'
  AND column_name = 'source_license'
  AND data_type = 'text';

SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'import_metadata'
  AND column_name = 'retrieved_at'
  AND data_type = 'timestamp with time zone';

-- 3) Índice existe
SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean'
  AND tablename = 'import_metadata'
  AND indexname = 'idx_import_metadata_source_url';

-- 4) Comentários existem
SELECT 1
FROM pg_description d
JOIN pg_class c ON c.oid = d.objoid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'clean'
  AND c.relname = 'import_metadata'
  AND d.objsubid IN (
    SELECT ordinal_position
    FROM information_schema.columns
    WHERE table_schema = 'clean'
      AND table_name = 'import_metadata'
      AND column_name IN ('source_url', 'source_license', 'retrieved_at')
  );

ROLLBACK;