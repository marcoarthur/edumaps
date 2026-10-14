-- Revert edumaps:analytics_views_materializadas from pg
-- Devolve a definição à view (lida da própria MV) e apaga a MV e a função.

BEGIN;

DROP FUNCTION analytics.refresh_views_ingestao();

DO $$
DECLARE
  v TEXT;
  def TEXT;
BEGIN
  FOREACH v IN ARRAY ARRAY['mobilidade_escola', 'acessibilidade_saude', 'esforco_fiscal_educacao'] LOOP
    def := pg_get_viewdef(format('analytics.%I', 'mv_' || v)::regclass, true);
    EXECUTE format('CREATE OR REPLACE VIEW analytics.%I AS %s', v, def);
    EXECUTE format('DROP MATERIALIZED VIEW analytics.%I', 'mv_' || v);
  END LOOP;
END $$;

COMMIT;
