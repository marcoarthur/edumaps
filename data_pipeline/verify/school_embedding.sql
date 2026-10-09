-- Verify edumaps:school_embedding on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'analytics' AND table_name = 'school_embedding';
    IF n <> 1 THEN
        RAISE EXCEPTION 'school_embedding: analytics.school_embedding ausente';
    END IF;

    SELECT count(*) INTO n FROM pg_extension WHERE extname = 'vector';
    IF n <> 1 THEN
        RAISE EXCEPTION 'school_embedding: extensão vector ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'analytics' AND tablename = 'school_embedding'
      AND indexname = 'idx_school_embedding_hnsw';
    IF n <> 1 THEN
        RAISE EXCEPTION 'school_embedding: índice HNSW idx_school_embedding_hnsw ausente';
    END IF;
END $$;

ROLLBACK;
