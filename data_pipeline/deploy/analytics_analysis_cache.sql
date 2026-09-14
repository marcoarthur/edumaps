-- Deploy edumaps:analytics_analysis_cache to pg
-- requires: schemas

BEGIN;

  CREATE TABLE analytics.analysis_cache (
    cache_key      text        PRIMARY KEY,
    analysis       text        NOT NULL,
    params         jsonb       NOT NULL,
    payload        jsonb       NOT NULL,
    source_version text,
    created_at     timestamptz NOT NULL DEFAULT NOW(),
    updated_at     timestamptz NOT NULL DEFAULT NOW(),
    expires_at     timestamptz
  );

  COMMENT ON TABLE analytics.analysis_cache IS
    'Cache compartilhado das análises R (edumapsr/Plumber) entre workers do backend.';
  COMMENT ON COLUMN analytics.analysis_cache.cache_key IS
    'SHA-1 canônico (JSON::PP->canonical) de {analysis, params, source_version} — estável entre processos.';
  COMMENT ON COLUMN analytics.analysis_cache.analysis IS
    'Nome da análise (ex: cluster_kmeans, city_summary).';
  COMMENT ON COLUMN analytics.analysis_cache.params IS
    'Parâmetros que afetam o resultado da análise (código IBGE, schema, tabela, features, ...).';
  COMMENT ON COLUMN analytics.analysis_cache.payload IS
    'Resposta JSON da análise, reutilizada por leitura-through.';
  COMMENT ON COLUMN analytics.analysis_cache.source_version IS
    'Versão do código de análise (edumapsr) que gerou o payload.';
  COMMENT ON COLUMN analytics.analysis_cache.expires_at IS
    'Expiração (24h). NULL = não expira.';

  CREATE INDEX idx_analysis_cache_analysis ON analytics.analysis_cache (analysis, source_version);
  CREATE INDEX idx_analysis_cache_expires   ON analytics.analysis_cache (expires_at)
    WHERE expires_at IS NOT NULL;

COMMIT;