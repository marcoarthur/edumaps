-- Deploy edumaps:analytics_views_materializadas to pg
-- requires: analytics_mobilidade_escola
-- requires: analytics_acessibilidade_saude
-- requires: analytics_esforco_fiscal_fundeb
-- requires: analytics_ausencia_visivel
--
-- #158 (dentro do fechamento da #156): com dado real, as três views
-- analíticas recalculam a agregação inteira a cada leitura. Medido em
-- 2026-10-14 no produto: ~1,3 s por leitura completa e 2,4 s para UMA
-- escola (o filtro não desce para a agregação).
--
-- Desenho:
-- - analytics.mv_<nome> = MATERIALIZED VIEW com a definição ATUAL da view
--   (pg_get_viewdef: a lógica não é duplicada aqui), índice único na chave
--   natural (exigido pelo REFRESH ... CONCURRENTLY) e índices de filtro.
-- - analytics.<nome> continua a existir como VIEW-fachada (SELECT * da MV):
--   o contrato para consumidores não muda, e os verifies antigos que olham
--   information_schema.views/columns — que NÃO listam matviews — seguem
--   válidos.
-- - analytics.refresh_views_ingestao() refresca as três (CONCURRENTLY);
--   o ingestion_runner chama-a ao fim de uma carga real bem-sucedida.

BEGIN;

DO $$
DECLARE
  v TEXT;
BEGIN
  FOREACH v IN ARRAY ARRAY['mobilidade_escola', 'acessibilidade_saude', 'esforco_fiscal_educacao'] LOOP
    EXECUTE format('CREATE MATERIALIZED VIEW analytics.%I AS %s',
                   'mv_' || v, pg_get_viewdef(format('analytics.%I', v)::regclass, true));
    EXECUTE format('CREATE OR REPLACE VIEW analytics.%I AS SELECT * FROM analytics.%I', v, 'mv_' || v);
  END LOOP;
END $$;

CREATE UNIQUE INDEX mv_mobilidade_escola_pk ON analytics.mv_mobilidade_escola (co_entidade);
CREATE UNIQUE INDEX mv_acessibilidade_saude_pk ON analytics.mv_acessibilidade_saude (co_entidade);
CREATE UNIQUE INDEX mv_esforco_fiscal_educacao_pk ON analytics.mv_esforco_fiscal_educacao (codigo_ibge, exercicio);
CREATE INDEX mv_esforco_fiscal_educacao_exercicio ON analytics.mv_esforco_fiscal_educacao (exercicio);

COMMENT ON MATERIALIZED VIEW analytics.mv_mobilidade_escola IS
'Materialização de analytics.mobilidade_escola (#158): mesma definição, chave co_entidade. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real.';
COMMENT ON MATERIALIZED VIEW analytics.mv_acessibilidade_saude IS
'Materialização de analytics.acessibilidade_saude (#158): mesma definição, chave co_entidade. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real.';
COMMENT ON MATERIALIZED VIEW analytics.mv_esforco_fiscal_educacao IS
'Materialização de analytics.esforco_fiscal_educacao (#158): mesma definição, chave (codigo_ibge, exercicio); computed_at = data do último refresh. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real.';

CREATE FUNCTION analytics.refresh_views_ingestao() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_mobilidade_escola;
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_acessibilidade_saude;
  REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_esforco_fiscal_educacao;
END $$;

COMMENT ON FUNCTION analytics.refresh_views_ingestao() IS
'Refresca as views analíticas materializadas (#158). Chamada pelo ingestion_runner ao fim de uma carga real bem-sucedida; também pode ser chamada à mão depois de recargas por outro caminho (ex.: Censo Escolar).';

COMMIT;
