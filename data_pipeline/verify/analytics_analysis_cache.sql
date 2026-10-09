-- Verify edumaps:analytics_analysis_cache from pg
-- requires: schemas
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'analytics' AND table_name = 'analysis_cache'
      AND column_name IN ('cache_key', 'analysis', 'params', 'payload',
                          'source_version', 'created_at', 'updated_at', 'expires_at');
    IF n <> 8 THEN
        RAISE EXCEPTION 'analytics_analysis_cache: esperava 8 colunas em analytics.analysis_cache, encontrei %', n;
    END IF;
END $$;

ROLLBACK;
