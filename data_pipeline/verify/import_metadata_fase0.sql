-- Verify edumaps:import_metadata_fase0 on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- 1) Colunas existem (e são anuláveis)
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'import_metadata'
      AND column_name IN ('source_url', 'source_license', 'retrieved_at')
      AND is_nullable = 'YES';
    IF n <> 3 THEN
        RAISE EXCEPTION 'import_metadata_fase0: esperava 3 colunas anuláveis (source_url/source_license/retrieved_at), encontrei %', n;
    END IF;

    -- 2) Tipos corretos
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'import_metadata'
      AND ( (column_name = 'source_url'     AND data_type = 'text')
         OR (column_name = 'source_license' AND data_type = 'text')
         OR (column_name = 'retrieved_at'   AND data_type = 'timestamp with time zone') );
    IF n <> 3 THEN
        RAISE EXCEPTION 'import_metadata_fase0: tipos incorretos (% de 3)', n;
    END IF;

    -- 3) Índice existe
    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'import_metadata'
      AND indexname = 'idx_import_metadata_source_url';
    IF n <> 1 THEN
        RAISE EXCEPTION 'import_metadata_fase0: índice idx_import_metadata_source_url ausente';
    END IF;

    -- 4) Comentários existem
    SELECT count(*) INTO n
    FROM pg_description d
    JOIN pg_class c ON c.oid = d.objoid
    JOIN pg_namespace ns ON ns.oid = c.relnamespace
    JOIN information_schema.columns col
      ON col.table_schema = 'clean' AND col.table_name = 'import_metadata'
     AND col.column_name IN ('source_url', 'source_license', 'retrieved_at')
     AND col.ordinal_position = d.objsubid
    WHERE ns.nspname = 'clean' AND c.relname = 'import_metadata';
    IF n < 3 THEN
        RAISE EXCEPTION 'import_metadata_fase0: comentários faltando (% de 3)', n;
    END IF;
END $$;

ROLLBACK;
