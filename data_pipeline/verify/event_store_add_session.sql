-- Verify edumaps:event_store_add_session on pg
-- Assere as colunas adicionadas ao event_store e o índice — padrão #160.
-- Schema `clean` como padrão do banco (ver verify/session_tracking.sql).

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'event_store'
      AND column_name IN ('session_id','gestor_id');
    IF n <> 2 THEN
        RAISE EXCEPTION 'event_store_add_session: colunas session_id/gestor_id ausentes';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'event_store'
      AND indexname = 'idx_event_store_session_created';
    IF n <> 1 THEN
        RAISE EXCEPTION 'event_store_add_session: índice idx_event_store_session_created ausente';
    END IF;
END $$;

ROLLBACK;