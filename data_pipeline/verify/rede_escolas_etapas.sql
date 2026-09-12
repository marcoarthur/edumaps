-- Verify edumaps:rede_escolas_etapas on pg

BEGIN;

  SELECT 1/COUNT(*) FROM pg_matviews WHERE schemaname = 'analytics' AND matviewname = 'mv_rede_escolas';
  SELECT 1/COUNT(*) FROM information_schema.columns
    WHERE table_schema = 'analytics' AND table_name = 'mv_rede_escolas'
      AND column_name IN ('total_etapas', 'media_etapas');
  SELECT 1/COUNT(*) FROM pg_proc WHERE proname = 'refresh_rede_escolas' AND pronamespace = 'analytics'::regnamespace;

ROLLBACK;