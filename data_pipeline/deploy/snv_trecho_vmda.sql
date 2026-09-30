-- Deploy edumaps:snv_trecho_vmda to pg
-- requires: antt_trecho_geodados
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- DNIT/INDE - SNV + VMDA (MALHA FEDERAL COM VOLUME ESTIMADO)
-- ATENÇÃO: DECISÃO JURÍDICA PENDENTE - REGISTRAR CONTRADIÇÃO EM ADR ANTES DE MATERIALIZAR
-- Camada espelhada no INDE declara Public Domain, mas catálogo GeoNetwork
-- traz texto padrão contraditório ("o governo concedeu o direito exclusivo...")
-- A camada VMDA é MODELAGEM (estimada a partir de PNCT, pedágios, matriz OD PNT 2016/2017)
-- NÃO é contagem real. Boa variável COMPARATIVA, NÃO substitui contagem real.
-- =================================================================

DROP TABLE IF EXISTS clean.snv_trecho_vmda;
CREATE TABLE clean.snv_trecho_vmda (
    id_trecho           BIGSERIAL PRIMARY KEY,
    concessionaria      TEXT,
    trecho              TEXT,                 -- código do trecho
    km_inicial          NUMERIC(10,3),
    km_final            NUMERIC(10,3),
    extensao_km         NUMERIC(10,3),
    uf                  CHAR(2),
    municipio           TEXT,
    codigo_ibge         TEXT,                 -- 7 dígitos IBGE
    -- VMDA (Volume Médio Diário Anual) - ESTIMADO
    vmda_total          INTEGER,              -- VMDa total (estimado)
    vmda_leve           INTEGER,              -- veículos leves (estimado)
    vmda_pesado         INTEGER,              -- veículos pesados (estimado)
    -- Metadados de modelagem
    ano_referencia_modelo SMALLINT,           -- ano da matriz OD de referência (ex.: 2017)
    fonte_modelagem     TEXT,                 -- 'PNCT' | 'pedagio' | 'matriz_OD_PNT'
    -- Geometria
    geometry            geometry(LineString, 4674),
    -- Metadados
    dt_carga            TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT uq_snv_trecho UNIQUE (concessionaria, trecho)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_snv_trecho_codigo_ibge ON clean.snv_trecho_vmda (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_snv_trecho_geometry ON clean.snv_trecho_vmda USING GIST (geometry);
CREATE INDEX IF NOT EXISTS idx_snv_trecho_vmda ON clean.snv_trecho_vmda (vmda_total);

-- FK para malha_municipio
ALTER TABLE clean.snv_trecho_vmda
  ADD CONSTRAINT fk_snv_trecho_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE SET NULL;

-- Comentários
COMMENT ON TABLE clean.snv_trecho_vmda IS 'SNV + VMDA (DNIT/INDE) - Volume Médio Diário Anual ESTIMADO por trecho. CAMADA É MODELAGEM, não medição. Origem: PNCT + pedágios + matriz OD PNT 2016/2017. DECISÃO JURÍDICA PENDENTE: INDE declara Public Domain mas GeoNetwork traz texto contraditório. Registrar contradição em ADR ANTES de materializar.';
COMMENT ON COLUMN clean.snv_trecho_vmda.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.snv_trecho_vmda.trecho IS 'Código do trecho';
COMMENT ON COLUMN clean.snv_trecho_vmda.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.snv_trecho_vmda.vmda_total IS 'VMDa total estimado (veículos/dia)';
COMMENT ON COLUMN clean.snv_trecho_vmda.vmda_leve IS 'VMDa veículos leves estimado';
COMMENT ON COLUMN clean.snv_trecho_vmda.vmda_pesado IS 'VMDa veículos pesados estimado';
COMMENT ON COLUMN clean.snv_trecho_vmda.ano_referencia_modelo IS 'Ano da matriz OD de referência (ex.: 2017)';
COMMENT ON COLUMN clean.snv_trecho_vmda.fonte_modelagem IS 'Fonte da modelagem: PNCT, pedagio, matriz_OD_PNT';
COMMENT ON COLUMN clean.snv_trecho_vmda.geometry IS 'Geometria do trecho (LineString, SRID 4674)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.snv_trecho_vmda'::text,
       'INDE DNIT SNV + VMDA'::text,
       'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_rodoviaria'::text,
       'Public Domain (INDE declara) / Texto contraditório no GeoNetwork - DECISÃO JURÍDICA PENDENTE'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: snv_trecho_vmda. VMDA É MODELAGEM (PNCT + pedágio + matriz OD PNT 2016/2017), NÃO contagem real. DECISÃO JURÍDICA PENDENTE sobre licença contraditória. Boa variável comparativa, NÃO substitui contagem real.'
FROM clean.snv_trecho_vmda;

COMMIT;