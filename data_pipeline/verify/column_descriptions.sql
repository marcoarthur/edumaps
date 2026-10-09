-- Verify edumaps:column_descriptions on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- Nenhuma coluna pode ficar sem descrição nas tabelas alvo.
    SELECT count(*) INTO n
    FROM pg_class c
    JOIN pg_namespace ns ON ns.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
    WHERE (ns.nspname, c.relname) IN (
        ('analytics', 'school_embedding'),
        ('clean',     'event_store'),
        ('clean',     'mv_escolas_scores'),
        ('clean',     'censo_escolas'),
        ('clean',     'school_indicators'),
        ('analytics', 'mv_rede_escolas'))
      AND col_description(c.oid, a.attnum) IS NULL;
    IF n > 0 THEN
        RAISE EXCEPTION 'column_descriptions: % coluna(s) sem descrição nas tabelas alvo', n;
    END IF;
END $$;

ROLLBACK;
