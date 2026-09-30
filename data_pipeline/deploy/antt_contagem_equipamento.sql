-- Deploy edumaps:antt_contagem_equipamento to pg
-- requires: antt_trecho_geodados
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- ANTT - CONTAGEM DE TRÁFEGO EM EQUIPAMENTOS DE MEDIÇÃO
-- Fonte: dados.antt.gov.br (painel/conjunto de dados de contagem)
-- Exposição a ruído e tráfego em trecho, com coordenada
-- Somente rodovias federais concedidas
-- =================================================================

DROP TABLE IF EXISTS clean.antt_contagem_equipamento;
CREATE TABLE clean.antt_contagem_equipamento (
    id_contagem           BIGSERIAL PRIMARY KEY,
    concessionaria        TEXT NOT NULL,
    trecho                TEXT NOT NULL,        -- código do trecho (FK para antt_trecho_geodados)
    km                    NUMERIC(10,3),
    latitude              NUMERIC(10,8),
    longitude             NUMERIC(11,8),
    -- Dados de tráfego
    data_contagem         DATE NOT NULL,
    volume_diario         INTEGER,              -- volume médio diário
    composicao_leve       INTEGER,              -- veículos leves
    composicao_pesado     INTEGER,              -- veículos pesados
    -- Metadados
    dt_carga              TIMESTAMPTZ DEFAULT NOW(),
    dt_snapshot           DATE NOT NULL,        -- data do snapshot mensal

    CONSTRAINT uq_antt_contagem UNIQUE (concessionaria, trecho, data_contagem, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_contagem_trecho ON clean.antt_contagem_equipamento (trecho);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_data ON clean.antt_contagem_equipamento (data_contagem);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_dt_snapshot ON clean.antt_contagem_equipamento (dt_snapshot);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_geometry ON clean.antt_contagem_equipamento USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4674)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- FK para antt_trecho_geodados
ALTER TABLE clean.antt_contagem_equipamento
  ADD CONSTRAINT fk_antt_contagem_trecho
  FOREIGN KEY (trecho) REFERENCES clean.antt_trecho_geodados(trecho)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.antt_contagem_equipamento IS 'ANTT contagem de tráfego em equipamentos de medição. Somente rodovias federais concedidas. JOIN com antt_trecho_geodados para município.';
COMMENT ON COLUMN clean.antt_contagem_equipamento.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.antt_contagem_equipamento.trecho IS 'Código do trecho (FK para antt_trecho_geodados)';
COMMENT ON COLUMN clean.antt_contagem_equipamento.data_contagem IS 'Data da contagem';
COMMENT ON COLUMN clean.antt_contagem_equipamento.volume_diario IS 'Volume médio diário de veículos';
COMMENT ON COLUMN clean.antt_contagem_equipamento.composicao_leve IS 'Veículos leves';
COMMENT ON COLUMN clean.antt_contagem_equipamento.composicao_pesado IS 'Veículos pesados';
COMMENT ON COLUMN clean.antt_contagem_equipamento.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_contagem_equipamento'::text,
       'API ANTT contagem de tráfego'::text,
       'https://dados.antt.gov.br'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_contagem_equipamento. Somente rodovias concedidas. KMZ requer GDAL/ogr - pré-converter para GPKG.'
FROM clean.antt_contagem_equipamento;

COMMIT;