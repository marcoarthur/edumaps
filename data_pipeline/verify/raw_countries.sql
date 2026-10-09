-- Verify edumaps:raw_countries on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.
--
-- A checagem de dados usa apenas clean.countries (materializada localmente).
-- A foreign table raw.countries_geo NÃO é consultada aqui: consultá-la aciona
-- o /vsicurl contra a rede, o que tornava o verify dependente de conectividade
-- (no CI resolvido pelo espelho local — db/fixtures/mirror_countries.py).

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n FROM pg_foreign_server WHERE srvname = 'fds_geojson';
    IF n <> 1 THEN
        RAISE EXCEPTION 'raw_countries: servidor FDW fds_geojson ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'raw' AND table_name = 'countries_geo';
    IF n <> 1 THEN
        RAISE EXCEPTION 'raw_countries: raw.countries_geo ausente';
    END IF;

    -- geography é tipo USER-DEFINED: o nome está em udt_name, não em data_type.
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'countries'
      AND column_name = 'geometry' AND udt_name = 'geography';
    IF n <> 1 THEN
        RAISE EXCEPTION 'raw_countries: clean.countries.geometry (geography) ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'countries'
      AND indexname IN ('ix_countries_geometry', 'ix_countries_name');
    IF n <> 2 THEN
        RAISE EXCEPTION 'raw_countries: esperava 2 índices em clean.countries, encontrei %', n;
    END IF;

    SELECT count(*) INTO n FROM clean.countries;
    IF n = 0 THEN
        RAISE EXCEPTION 'raw_countries: clean.countries vazia';
    END IF;
END $$;

ROLLBACK;
