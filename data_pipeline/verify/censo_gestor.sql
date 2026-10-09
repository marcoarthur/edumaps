-- Verify edumaps:censo_gestor on pg
-- Antes não verificava nada ('-- XXX Add verifications here.'). Agora assere de
-- facto a tabela e o índice criados pelo change — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'censo_gestor';
    IF n <> 1 THEN
        RAISE EXCEPTION 'censo_gestor: clean.censo_gestor ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'censo_gestor'
      AND indexname = 'idx_censo_gestor_co_entidade';
    IF n <> 1 THEN
        RAISE EXCEPTION 'censo_gestor: índice idx_censo_gestor_co_entidade ausente';
    END IF;
END $$;

ROLLBACK;
