-- Verify edumaps:nro_etapas on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'censo_escolas' AND column_name = 'nro_etapas';
    IF n <> 1 THEN
        RAISE EXCEPTION 'nro_etapas: clean.censo_escolas.nro_etapas ausente';
    END IF;
END $$;

ROLLBACK;
