-- Verify edumaps:schemas on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION): o Sqitch 1.6.1 só
-- considera a verificação falhada quando o script produz ERRO. Um SELECT que
-- devolve 'f' passa como ok — ver issue #160.

BEGIN;

DO $$
DECLARE
    n  integer;
    sp text := current_setting('search_path');
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.schemata
    WHERE schema_name IN ('raw', 'clean', 'analytics', 'postgis', 'contrib');
    IF n <> 5 THEN
        RAISE EXCEPTION 'schemas: esperava raw/clean/analytics/postgis/contrib (5 schemas), encontrei %', n;
    END IF;

    IF sp NOT LIKE '%clean%' OR sp NOT LIKE '%analytics%' OR sp NOT LIKE '%raw%' THEN
        RAISE EXCEPTION 'schemas: search_path efetivo sem clean/analytics/raw (%)', sp;
    END IF;
END $$;

ROLLBACK;
