-- Verify edumaps:analytics_municipios_consolidado on pg
-- Antes era um '-- TODO: SELECT 1' (não verificava nada). Agora assere a
-- materialized view e colunas-chave — ver issue #160.
--
-- Nota: information_schema.columns NÃO lista colunas de materialized views;
-- por isso a checagem usa pg_matviews + pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM pg_matviews
    WHERE schemaname = 'analytics' AND matviewname = 'mv_municipios_consolidado';
    IF n <> 1 THEN
        RAISE EXCEPTION 'analytics_municipios_consolidado: matview analytics.mv_municipios_consolidado ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'analytics' AND c.relname = 'mv_municipios_consolidado'
      AND a.attname IN ('co_municipio', 'sg_uf', 'populacao_estimada', 'pib_total');
    IF n <> 4 THEN
        RAISE EXCEPTION 'analytics_municipios_consolidado: esperava 4 colunas-chave, encontrei %', n;
    END IF;
END $$;

ROLLBACK;
