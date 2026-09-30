-- Deploy edumaps:renavam_frota_municipio to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- TRANSPORTES - RENAVAM FROTA AGREGADA POR MUNICÍPIO
-- Fonte: dados.transportes.gov.br/dataset/frota-por-municipio
-- Domínio público, municipal, mensal desde mai/2013
-- =================================================================

DROP TABLE IF EXISTS clean.renavam_frota_municipio;
CREATE TABLE clean.renavam_frota_municipio (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    ano               SMALLINT NOT NULL,  -- ano de referência
    mes               SMALLINT NOT NULL,  -- mês (1-12)
    -- Frota por tipo de veículo
    automoveis        INTEGER,
    caminhao          INTEGER,
    caminhao_trator   INTEGER,
    micro_onibus      INTEGER,
    moto              INTEGER,
    onibus            INTEGER,
    outros            INTEGER,
    trator_rodas      INTEGER,
    reboque           INTEGER,
    semi_reboque      INTEGER,
    -- Total
    total_frota       INTEGER,
    -- Metadados
    dt_snapshot       DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_renavam_frota_municipio PRIMARY KEY (codigo_ibge, ano, mes, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_renavam_frota_codigo_ibge ON clean.renavam_frota_municipio (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_renavam_frota_ano_mes ON clean.renavam_frota_municipio (ano, mes);
CREATE INDEX IF NOT EXISTS idx_renavam_frota_dt_snapshot ON clean.renavam_frota_municipio (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.renavam_frota_municipio
  ADD CONSTRAINT fk_renavam_frota_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.renavam_frota_municipio IS 'RENAVAM frota agregada por município/mês (domínio público, mensal desde mai/2013). Não por veículo individual.';
COMMENT ON COLUMN clean.renavam_frota_municipio.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.renavam_frota_municipio.ano IS 'Ano de referência';
COMMENT ON COLUMN clean.renavam_frota_municipio.mes IS 'Mês (1-12)';
COMMENT ON COLUMN clean.renavam_frota_municipio.total_frota IS 'Total da frota municipal';
COMMENT ON COLUMN clean.renavam_frota_municipio.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.renavam_frota_municipio'::text,
       'API Transportes RENAVAM frota'::text,
       'https://dados.transportes.gov.br/dataset/frota-por-municipio'::text,
       'CC-BY-4.0 (Transportes)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: renavam_frota_municipio. Domínio público, mensal desde mai/2013. Não confundir com RENAEST (sinistros por localidade).'
FROM clean.renavam_frota_municipio;

COMMIT;