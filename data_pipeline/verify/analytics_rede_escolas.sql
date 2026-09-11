-- Verify edumaps:analytics_rede_escolas on pg

BEGIN;

  SELECT 1/COUNT(*) FROM pg_matviews WHERE schemaname = 'analytics' AND matviewname = 'mv_rede_escolas';
  SELECT 1/COUNT(*) FROM pg_proc WHERE proname = 'refresh_rede_escolas' AND pronamespace = 'analytics'::regnamespace;

ROLLBACK;