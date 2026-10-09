-- Verify edumaps:extensions on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    obrigatorias text[] := ARRAY[
        'postgis', 'postgis_raster', 'postgis_sfcgal', 'postgis_topology',
        'fuzzystrmatch', 'address_standardizer', 'uuid-ossp', 'unaccent', 'ogr_fdw'];
    faltando text;
    n integer;
BEGIN
    -- 1) as 9 extensões que o deploy instala
    SELECT string_agg(e, ', ') INTO faltando
    FROM unnest(obrigatorias) e
    WHERE e NOT IN (SELECT extname FROM pg_extension);
    IF faltando IS NOT NULL THEN
        RAISE EXCEPTION 'extensions: faltam extensões: %', faltando;
    END IF;

    -- 2) extensões nos schemas corretos
    SELECT count(*) INTO n
    FROM pg_extension x
    JOIN pg_namespace ns ON ns.oid = x.extnamespace
    WHERE (x.extname = 'postgis'              AND ns.nspname = 'postgis')
       OR (x.extname = 'postgis_raster'       AND ns.nspname = 'postgis')
       OR (x.extname = 'ogr_fdw'              AND ns.nspname = 'postgis')
       OR (x.extname = 'fuzzystrmatch'        AND ns.nspname = 'contrib')
       OR (x.extname = 'address_standardizer' AND ns.nspname = 'contrib')
       OR (x.extname = 'unaccent'             AND ns.nspname = 'contrib');
    IF n <> 6 THEN
        RAISE EXCEPTION 'extensions: % de 6 extensões no schema esperado', n;
    END IF;
END $$;

ROLLBACK;
