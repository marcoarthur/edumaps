-- Deploy edumaps:recife_transporte_escolar to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- RECIFE - TRANSPORTE ESCOLAR (CKAN)
-- ATENÇÃO: ODbL share-alike. LEITURA PERMITIDA; MATERIALIZAÇÃO SOB
-- SHARE-ALIKE É DECISÃO DO JURÍDICO. Ficha vale como PROVA DE VIABILIDADE
-- do indicador de transporte escolar com chave de escola.
-- =================================================================

DROP TABLE IF EXISTS clean.recife_transporte_escolar;
CREATE TABLE clean.recife_transporte_escolar (
    co_entidade         BIGINT NOT NULL,      -- código INEP da escola (chave para censo_escolas)
    ano                 SMALLINT NOT NULL,    -- ano de referência
    vagas_transporte    INTEGER,              -- vagas de transporte escolar por unidade/turno
    turno               TEXT,                 -- manhã, tarde, integral, etc.
    -- Metadados
    dt_snapshot         DATE NOT NULL,        -- data do snapshot

    CONSTRAINT pk_recife_transporte_escolar PRIMARY KEY (co_entidade, ano, turno, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_recife_transporte_co_entidade ON clean.recife_transporte_escolar (co_entidade);
CREATE INDEX IF NOT EXISTS idx_recife_transporte_ano ON clean.recife_transporte_escolar (ano);



-- Comentários
COMMENT ON TABLE clean.recife_transporte_escolar IS 'Transporte escolar Recife (CKAN) - ODbL share-alike. LEITURA PERMITIDA; MATERIALIZAÇÃO SOB SHARE-ALIKE É DECISÃO DO JURÍDICO. Ficha vale como PROVA DE VIABILIDADE do indicador de transporte escolar com chave de escola. Agregar a no mínimo zona OD antes de armazenar.';
COMMENT ON COLUMN clean.recife_transporte_escolar.co_entidade IS 'Código INEP da escola (FK para censo_escolas)';
COMMENT ON COLUMN clean.recife_transporte_escolar.ano IS 'Ano de referência';
COMMENT ON COLUMN clean.recife_transporte_escolar.vagas_transporte IS 'Vagas de transporte escolar por unidade/turno';
COMMENT ON COLUMN clean.recife_transporte_escolar.turno IS 'Turno: manhã, tarde, integral, etc.';
COMMENT ON COLUMN clean.recife_transporte_escolar.dt_snapshot IS 'Data do snapshot';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.recife_transporte_escolar'::text,
       'CKAN Recife transporte escolar'::text,
       'https://dados.recife.pe.gov.br'::text,
       'ODbL 1.0 (share-alike) - MATERIALIZAÇÃO SOB SHARE-ALIKE EXIGE DECISÃO JURÍDICA'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: recife_transporte_escolar. ODbL share-alike. LEITURA PERMITIDA; materialização sob share-alike é decisão do jurídico. Ficha = prova de viabilidade do indicador escolar. Agregar a no mínimo zona OD antes de armazenar.'
FROM clean.recife_transporte_escolar;

COMMIT;