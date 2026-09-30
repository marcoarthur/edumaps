-- Deploy edumaps:inmet_bdmep to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- INMET BDMEP - SÉRIE DIÁRIA HISTÓRICA DE ESTAÇÕES (26 ANOS)
-- Fonte: https://dados.inmet.gov.br/bdmep/estacao
-- 26 anos de série diária, API sem autenticação
-- Base para normalização climática
-- =================================================================

DROP TABLE IF EXISTS clean.inmet_bdmep;
CREATE TABLE clean.inmet_bdmep (
    codigo_estacao    TEXT NOT NULL,       -- código da estação INMET
    codigo_ibge       TEXT,                -- 7 dígitos IBGE (pode ser nulo se estação não mapeada)
    uf                CHAR(2),
    data              DATE NOT NULL,       -- data da observação
    -- Variáveis meteorológicas diárias
    precipitacao_mm   NUMERIC(6,2),        -- precipitação total (mm)
    pressao_atm_hpa   NUMERIC(7,2),        -- pressão atmosférica (hPa)
    pressao_max_hpa   NUMERIC(7,2),        -- pressão máxima (hPa)
    pressao_min_hpa   NUMERIC(7,2),        -- pressão mínima (hPa)
    radiacao_kj_m2    NUMERIC(10,2),       -- radiação global (kJ/m²)
    temp_ar_max_c     NUMERIC(5,2),        -- temp. ar máxima (°C)
    temp_ar_min_c     NUMERIC(5,2),        -- temp. ar mínima (°C)
    temp_ar_media_c   NUMERIC(5,2),        -- temp. ar média (°C)
    temp_orvalho_max  NUMERIC(5,2),        -- temp. ponto orvalho máxima (°C)
    temp_orvalho_min  NUMERIC(5,2),        -- temp. ponto orvalho mínima (°C)
    temp_orvalho_med  NUMERIC(5,2),        -- temp. ponto orvalho média (°C)
    umid_max_pct      NUMERIC(5,2),        -- umidade relativa máxima (%)
    umid_min_pct      NUMERIC(5,2),        -- umidade relativa mínima (%)
    umid_med_pct      NUMERIC(5,2),        -- umidade relativa média (%)
    vento_vel_m_s     NUMERIC(5,2),        -- velocidade do vento (m/s)
    vento_raj_max     NUMERIC(5,2),        -- rajada máxima (m/s)
    vento_dir_graus   SMALLINT,            -- direção do vento (graus)
    evap_mm           NUMERIC(6,2),        -- evaporação (mm)
    -- Metadados
    dt_carga          TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT pk_inmet_bdmep PRIMARY KEY (codigo_estacao, data)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_inmet_bdmep_codigo_ibge ON clean.inmet_bdmep (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_inmet_bdmep_data ON clean.inmet_bdmep (data);
CREATE INDEX IF NOT EXISTS idx_inmet_bdmep_estacao ON clean.inmet_bdmep (codigo_estacao);
CREATE INDEX IF NOT EXISTS idx_inmet_bdmep_uf ON clean.inmet_bdmep (uf);

-- FK para malha_municipio (opcional, estação pode não ter município mapeado)
ALTER TABLE clean.inmet_bdmep
  ADD CONSTRAINT fk_inmet_bdmep_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE SET NULL;

-- Comentários
COMMENT ON TABLE clean.inmet_bdmep IS 'INMET BDMEP - série diária histórica de estações meteorológicas (26 anos). API sem autenticação. Base para normalização climática.';
COMMENT ON COLUMN clean.inmet_bdmep.codigo_estacao IS 'Código da estação INMET';
COMMENT ON COLUMN clean.inmet_bdmep.codigo_ibge IS 'Código IBGE do município onde a estação está localizada (pode ser nulo)';
COMMENT ON COLUMN clean.inmet_bdmep.uf IS 'UF da estação';
COMMENT ON COLUMN clean.inmet_bdmep.data IS 'Data da observação diária';
COMMENT ON COLUMN clean.inmet_bdmep.precipitacao_mm IS 'Precipitação total diária (mm)';
COMMENT ON COLUMN clean.inmet_bdmep.temp_ar_max_c IS 'Temperatura do ar máxima diária (°C)';
COMMENT ON COLUMN clean.inmet_bdmep.temp_ar_min_c IS 'Temperatura do ar mínima diária (°C)';
COMMENT ON COLUMN clean.inmet_bdmep.temp_ar_media_c IS 'Temperatura do ar média diária (°C)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.inmet_bdmep'::text,
       'API INMET BDMEP'::text,
       'https://dados.inmet.gov.br/bdmep/estacao'::text,
       'CC-BY-4.0 (INMET)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: inmet_bdmep. Série diária 26 anos. Base para normalização climática.'
FROM clean.inmet_bdmep;

COMMIT;