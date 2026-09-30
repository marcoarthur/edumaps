-- Deploy edumaps:antt_trecho_geodados to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- ANTT - GEODADOS DE TRECHOS RODOVIÁRIOS (trecho → município)
-- Fonte: dados.antt.gov.br/dataset/trechos
-- RESOLVE: trecho → município (via Concessionaria;Trecho;Km_Inicial;Km_Final;Municipio)
-- =================================================================

DROP TABLE IF EXISTS clean.antt_trecho_geodados;
CREATE TABLE clean.antt_trecho_geodados (
    concessionaria        TEXT NOT NULL,
    trecho                TEXT NOT NULL,        -- código do trecho
    km_inicial            NUMERIC(10,3),
    km_final              NUMERIC(10,3),
    extensao_km           NUMERIC(10,3),
    uf                    CHAR(2),
    municipio             TEXT,                 -- nome do município
    codigo_ibge           TEXT,                 -- 7 dígitos IBGE (quando disponível)
    -- Geometria do trecho (linestring)
    geometry              geometry(LineString, 4674),

    CONSTRAINT pk_antt_trecho_geodados PRIMARY KEY (concessionaria, trecho)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_trecho_codigo_ibge ON clean.antt_trecho_geodados (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_antt_trecho_geometry ON clean.antt_trecho_geodados USING GIST (geometry);

-- FK para malha_municipio
ALTER TABLE clean.antt_trecho_geodados
  ADD CONSTRAINT fk_antt_trecho_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE SET NULL;

-- Unique constraint on trecho for FK from antt_contagem_equipamento
ALTER TABLE clean.antt_trecho_geodados
  ADD CONSTRAINT uq_antt_trecho_geodados_trecho UNIQUE (trecho);

-- Comentários
COMMENT ON TABLE clean.antt_trecho_geodados IS 'Geodados ANTT de trechos rodoviários — resolve trecho → município (código IBGE). JOIN OBRIGATÓRIO com antt_acidente_trecho para resolver município do acidente.';
COMMENT ON COLUMN clean.antt_trecho_geodados.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.antt_trecho_geodados.trecho IS 'Código do trecho (chave de join com antt_acidente_trecho)';
COMMENT ON COLUMN clean.antt_trecho_geodados.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.antt_trecho_geodados.geometry IS 'Geometria do trecho (LineString, SRID 4674)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_trecho_geodados'::text,
       'API ANTT trechos'::text,
       'https://dados.antt.gov.br/dataset/trechos'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_trecho_geodados. Resolve trecho → município para antt_acidente_trecho.'
FROM clean.antt_trecho_geodados;

COMMIT;