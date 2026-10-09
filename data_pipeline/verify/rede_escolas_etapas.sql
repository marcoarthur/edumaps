-- Verify edumaps:rede_escolas_etapas on pg
-- Correção: o script original usava information_schema.columns, que NÃO lista
-- colunas de materialized views. O `1/COUNT(*)` dava divisão por zero sempre,
-- mesmo com o change deployed — ou seja, o verify nunca passava (issue #160).

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM pg_matviews
    WHERE schemaname = 'analytics' AND matviewname = 'mv_rede_escolas';
    IF n <> 1 THEN
        RAISE EXCEPTION 'rede_escolas_etapas: matview analytics.mv_rede_escolas ausente';
    END IF;

    -- pg_attribute, não information_schema.columns (matview não aparece lá).
    SELECT count(*) INTO n
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'analytics' AND c.relname = 'mv_rede_escolas'
      AND a.attname IN ('total_etapas', 'media_etapas');
    IF n <> 2 THEN
        RAISE EXCEPTION 'rede_escolas_etapas: esperava total_etapas/media_etapas em mv_rede_escolas, encontrei %', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'analytics' AND p.proname = 'refresh_rede_escolas';
    IF n < 1 THEN
        RAISE EXCEPTION 'rede_escolas_etapas: função analytics.refresh_rede_escolas ausente';
    END IF;
END $$;

ROLLBACK;
