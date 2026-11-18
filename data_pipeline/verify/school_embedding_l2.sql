-- Verify edumaps:school_embedding_l2 on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    ops text;
BEGIN
    SELECT opc.opcname INTO ops
    FROM pg_index ix
    JOIN pg_class ic    ON ic.oid = ix.indexrelid
    JOIN pg_namespace n ON n.oid = ic.relnamespace
    JOIN pg_opclass opc ON opc.oid = ix.indclass[0]
    WHERE n.nspname = 'analytics' AND ic.relname = 'idx_school_embedding_hnsw';

    IF ops IS NULL THEN
        RAISE EXCEPTION 'school_embedding_l2: índice idx_school_embedding_hnsw ausente';
    END IF;
    IF ops <> 'vector_l2_ops' THEN
        RAISE EXCEPTION 'school_embedding_l2: índice com % (esperado vector_l2_ops)', ops;
    END IF;
END $$;

ROLLBACK;
