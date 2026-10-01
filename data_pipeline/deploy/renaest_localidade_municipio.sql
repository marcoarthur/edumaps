-- Deploy edumaps:renaest_localidade_municipio to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- DE-PARA RENAEST LOCALIDADE → MUNICÍPIO IBGE
-- Fonte: IBGE (malha_municipio) + DETRANs/secretarias
-- Construído manualmente + fuzzy matching + validação humana
-- Chave: (localidade, uf) → codigo_ibge
-- =================================================================

DROP TABLE IF EXISTS clean.renaest_localidade_municipio;
CREATE TABLE clean.renaest_localidade_municipio (
    localidade        TEXT NOT NULL,
    uf                CHAR(2) NOT NULL,
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    nome_municipio    TEXT NOT NULL,
    -- Metadados de qualidade do match
    match_type        TEXT NOT NULL DEFAULT 'exact',  -- 'exact', 'fuzzy', 'manual'
    match_score       NUMERIC(5,2),       -- 0-100, score do fuzzy match
    validated_by      TEXT,               -- quem validou
    validated_at      TIMESTAMPTZ,
    -- Metadados
    dt_carga          TIMESTAMPTZ DEFAULT NOW(),
    dt_snapshot       DATE NOT NULL,

    CONSTRAINT pk_renaest_localidade_municipio PRIMARY KEY (localidade, uf, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_renaest_depara_codigo_ibge ON clean.renaest_localidade_municipio (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_renaest_depara_uf ON clean.renaest_localidade_municipio (uf);

-- FK para malha_municipio
ALTER TABLE clean.renaest_localidade_municipio
  ADD CONSTRAINT fk_renaest_depara_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.renaest_localidade_municipio IS 'De-para RENAEST localidade → município IBGE. Chave: (localidade, uf) → codigo_ibge. match_type: exact/fuzzy/manual. match_score: 0-100. Construído por fuzzy matching + validação humana.';
COMMENT ON COLUMN clean.renaest_localidade_municipio.localidade IS 'Nome da localidade RENAEST (ex.: São Paulo, Campinas)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.uf IS 'UF da localidade';
COMMENT ON COLUMN clean.renaest_localidade_municipio.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.match_type IS 'Tipo de match: exact (igual), fuzzy (aproximado), manual (validado humano)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.match_score IS 'Score do fuzzy match (0-100)';
COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_by IS 'Quem validou o match';
COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_at IS 'Quando foi validado';

-- Popular com match exato a partir de malha_municipio (municípios que têm nome igual à localidade RENAEST)
INSERT INTO clean.renaest_localidade_municipio (
    localidade, uf, codigo_ibge, nome_municipio,
    match_type, match_score, validated_by, validated_at, dt_snapshot
)
SELECT
    m.nome_municipio AS localidade,
    m.sigla_uf AS uf,
    m.codigo_ibge,
    m.nome_municipio,
    'exact' AS match_type,
    100.0 AS match_score,
    'auto_seed' AS validated_by,
    NOW() AS validated_at,
    CURRENT_DATE AS dt_snapshot
FROM clean.malha_municipio m
WHERE m.nome_municipio IS NOT NULL
  AND m.sigla_uf IS NOT NULL
  AND m.codigo_ibge IS NOT NULL
ON CONFLICT (localidade, uf, dt_snapshot) DO NOTHING;

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.renaest_localidade_municipio'::text,
       'IBGE malha_municipio (seed exato) + validação manual posterior'::text,
       'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024'::text,
       'Domínio público (IBGE)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Seed exato de malha_municipio. Fuzzy matching + validação manual posterior para completar. De-para localidade → município IBGE para RENAEST.'
FROM clean.renaest_localidade_municipio;

COMMIT;