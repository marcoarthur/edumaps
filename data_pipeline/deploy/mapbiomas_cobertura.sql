-- Deploy edumaps:mapbiomas_cobertura to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- MAPBIOMAS - COBERTURA/USO DO SOLO POR MUNICÍPIO/ANO/CLASSE
-- Fonte: https://mapbiomas.org/download/collection/{colecao}/municipios
-- ATENÇÃO: Fixar a COLEÇÃO (ex.: collection9), não o ano.
-- A URL por ano morre; ETL que interpola %d quebra silenciosamente.
-- =================================================================

DROP TABLE IF EXISTS clean.mapbiomas_cobertura;
CREATE TABLE clean.mapbiomas_cobertura (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    ano               SMALLINT NOT NULL,  -- ano de referência (ex.: 2023)
    colecao           TEXT NOT NULL,      -- ex.: 'collection9'
    classe            TEXT NOT NULL,      -- ex.: '3.1.1', '3.2', '4'
    classe_desc       TEXT,               -- descrição legível
    area_ha           NUMERIC,            -- área em hectares
    area_km2          NUMERIC,            -- área em km² (derivado)
    -- Metadados
    data_acessada     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT pk_mapbiomas_cobertura PRIMARY KEY (codigo_ibge, ano, colecao, classe)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_mapbiomas_codigo_ibge ON clean.mapbiomas_cobertura (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_mapbiomas_ano ON clean.mapbiomas_cobertura (ano);
CREATE INDEX IF NOT EXISTS idx_mapbiomas_classe ON clean.mapbiomas_cobertura (classe);
CREATE INDEX IF NOT EXISTS idx_mapbiomas_colecao ON clean.mapbiomas_cobertura (colecao);

-- FK para malha_municipio
ALTER TABLE clean.mapbiomas_cobertura
  ADD CONSTRAINT fk_mapbiomas_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.mapbiomas_cobertura IS 'MapBiomas cobertura/uso do solo por município/ano/classe. Fonte: collection fixa (ex.: collection9). Granularidade 30m. Arealizar sobre área de influência da escola, não sobre centroide.';
COMMENT ON COLUMN clean.mapbiomas_cobertura.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.mapbiomas_cobertura.ano IS 'Ano de referência do dado (ex.: 2023)';
COMMENT ON COLUMN clean.mapbiomas_cobertura.colecao IS 'Coleção MapBiomas (ex.: collection9) — FIXAR, não interpolar ano';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe IS 'Código da classe MapBiomas (ex.: 3.1.1, 3.2, 4)';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe_desc IS 'Descrição legível da classe';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_ha IS 'Área em hectares';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_km2 IS 'Área em km² (area_ha / 100)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.mapbiomas_cobertura'::text,
       'MapBiomas collection9 municipios'::text,
       'https://mapbiomas.org/download/collection/collection9/municipios'::text,
       'CC-BY-4.0 (MapBiomas)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: mapbiomas_cobertura. Coleção FIXA (collection9), não interpolar ano.'
FROM clean.mapbiomas_cobertura;

COMMIT;