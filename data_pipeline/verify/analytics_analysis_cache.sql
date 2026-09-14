-- Verify edumaps:analytics_analysis_cache from pg
-- requires: schemas

SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name   = 'analysis_cache'
  AND column_name  IN ('cache_key', 'analysis', 'params', 'payload',
                       'source_version', 'created_at', 'updated_at', 'expires_at')
HAVING COUNT(*) = 8;