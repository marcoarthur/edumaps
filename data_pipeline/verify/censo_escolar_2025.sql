-- Verify edumaps:censo_escolar_2025 on pg
-- Antes não verificava nada ('-- XXX Add verifications here.'). Agora assere a
-- tabela, a coluna geometry e o índice — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'censo_escolas';
    IF n <> 1 THEN
        RAISE EXCEPTION 'censo_escolar_2025: clean.censo_escolas ausente';
    END IF;

    -- geometry é tipo USER-DEFINED: o nome está em udt_name, não em data_type.
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'censo_escolas'
      AND column_name = 'geometry' AND udt_name = 'geometry';
    IF n <> 1 THEN
        RAISE EXCEPTION 'censo_escolar_2025: coluna geometry (geometry) ausente em clean.censo_escolas';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'censo_escolas'
      AND indexname = 'idx_censo_escolas_geom';
    IF n <> 1 THEN
        RAISE EXCEPTION 'censo_escolar_2025: índice idx_censo_escolas_geom ausente';
    END IF;
END $$;

ROLLBACK;
