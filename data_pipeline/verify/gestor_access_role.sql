-- Verify edumaps:gestor_access_role from pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'gestores' AND column_name = 'access_role';
    IF n <> 1 THEN
        RAISE EXCEPTION 'gestor_access_role: clean.gestores.access_role ausente';
    END IF;
END $$;

ROLLBACK;
