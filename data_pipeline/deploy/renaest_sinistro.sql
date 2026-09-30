-- Deploy edumaps:renaest_sinistro to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- RENAEST - SINISTROS AGREGADOS POR LOCALIDADE
-- Fonte: dados.transportes.gov.br/dataset/renatest-sinistro
-- AGREGAÇÃO: por localidade (não município) — requer de-para localidade → município
-- A fonte NÃO publica o de-para; construir e versionar é parte do escopo
-- =================================================================

DROP TABLE IF EXISTS clean.renaest_sinistro;
CREATE TABLE clean.renaest_sinistro (
    id_sinistro           BIGSERIAL PRIMARY KEY,
    -- Localização (chave original da fonte)
    localidade            TEXT NOT NULL,        -- localidade do sinistro (ex.: 'São Paulo', 'Campinas')
    uf                    CHAR(2),
    -- Dados do sinistro
    data_sinistro         DATE NOT NULL,
    tipo_sinistro         TEXT,                 -- colisão, atropelamento, capotamento, etc.
    classificacao         TEXT,                 -- com vítima fatal, com vítima ferida, sem vítima
    -- Vítimas
    mortos                INTEGER DEFAULT 0,
    feridos_graves        INTEGER DEFAULT 0,
    feridos_leves         INTEGER DEFAULT 0,
    ilesos                INTEGER DEFAULT 0,
    -- Veículos
    veiculos_envolvidos   INTEGER,
    -- De-para para município (construído e versionado)
    codigo_ibge           TEXT,                 -- 7 dígitos IBGE (após join com de-para localidade → município)
    -- Metadados
    dt_carga              TIMESTAMPTZ DEFAULT NOW(),
    dt_snapshot           DATE NOT NULL,        -- data do snapshot mensal

    CONSTRAINT uq_renaest_sinistro UNIQUE (localidade, uf, data_sinistro, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_renaest_data ON clean.renaest_sinistro (data_sinistro);
CREATE INDEX IF NOT EXISTS idx_renaest_localidade ON clean.renaest_sinistro (localidade, uf);
CREATE INDEX IF NOT EXISTS idx_renaest_codigo_ibge ON clean.renaest_sinistro (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_renaest_dt_snapshot ON clean.renaest_sinistro (dt_snapshot);

-- FK para malha_municipio (opcional - pode ser nulo se de-para não resolver)
ALTER TABLE clean.renaest_sinistro
  ADD CONSTRAINT fk_renaest_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE SET NULL;

-- Comentários
COMMENT ON TABLE clean.renaest_sinistro IS 'Sinistros RENAEST agregados por localidade (não município). Requer de-para localidade → município (construído e versionado). Agrega por localidade/UF/data. NÃO expor por escola.';
COMMENT ON COLUMN clean.renaest_sinistro.localidade IS 'Localidade do sinistro (chave original da fonte)';
COMMENT ON COLUMN clean.renaest_sinistro.uf IS 'UF';
COMMENT ON COLUMN clean.renaest_sinistro.data_sinistro IS 'Data do sinistro';
COMMENT ON COLUMN clean.renaest_sinistro.tipo_sinistro IS 'Tipo: colisão, atropelamento, capotamento, etc.';
COMMENT ON COLUMN clean.renaest_sinistro.classificacao IS 'Classificação: com vítima fatal, com vítima ferida, sem vítima';
COMMENT ON COLUMN clean.renaest_sinistro.codigo_ibge IS 'Código IBGE do município (após join com de-para localidade → município)';
COMMENT ON COLUMN clean.renaest_sinistro.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.renaest_sinistro'::text,
       'API Transportes RENAEST sinistro'::text,
       'https://dados.transportes.gov.br/dataset/renatest-sinistro'::text,
       'CC-BY-4.0 (Transportes)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: renaest_sinistro. Agrega por localidade (não município). De-para localidade → município versionado é parte do escopo.'
FROM clean.renaest_sinistro;

COMMIT;