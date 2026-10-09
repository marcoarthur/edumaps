-- Verify edumaps:scores_view on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.views
    WHERE table_schema = 'clean' AND table_name = 'censo_escolas_scores';
    IF n <> 1 THEN
        RAISE EXCEPTION 'scores_view: view clean.censo_escolas_scores ausente';
    END IF;
END $$;

ROLLBACK;
