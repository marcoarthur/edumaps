-- Verify edumaps:analytics_views_materializadas on pg
--
-- DO/RAISE EXCEPTION (issue #160). Matviews conferidas por pg_matviews
-- (information_schema não as lista).

BEGIN;

DO $$
DECLARE
  v TEXT;
  n_view BIGINT;
  n_mv BIGINT;
BEGIN
  FOREACH v IN ARRAY ARRAY['mobilidade_escola', 'acessibilidade_saude', 'esforco_fiscal_educacao'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'analytics' AND matviewname = 'mv_' || v) THEN
      RAISE EXCEPTION 'analytics_views_materializadas: falta a matview analytics.mv_%', v;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_views WHERE schemaname = 'analytics' AND viewname = v
                    AND definition LIKE '%mv_' || v || '%') THEN
      RAISE EXCEPTION 'analytics_views_materializadas: analytics.% não é a fachada da matview', v;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'analytics' AND tablename = 'mv_' || v
                    AND indexdef LIKE 'CREATE UNIQUE INDEX%') THEN
      RAISE EXCEPTION 'analytics_views_materializadas: mv_% sem índice único (REFRESH CONCURRENTLY falharia)', v;
    END IF;
    EXECUTE format('SELECT count(*) FROM analytics.%I', v) INTO n_view;
    EXECUTE format('SELECT count(*) FROM analytics.%I', 'mv_' || v) INTO n_mv;
    IF n_view <> n_mv THEN
      RAISE EXCEPTION 'analytics_views_materializadas: fachada % (%) ≠ matview (%)', v, n_view, n_mv;
    END IF;
  END LOOP;

  IF to_regprocedure('analytics.refresh_views_ingestao()') IS NULL THEN
    RAISE EXCEPTION 'analytics_views_materializadas: falta analytics.refresh_views_ingestao()';
  END IF;
END $$;

ROLLBACK;
