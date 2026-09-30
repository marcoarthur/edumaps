-- Deploy edumaps:inmet_alerta to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- INMET ALERTA-AS (CAP 1.2) - EVENTOS METEOROLÓGICOS QUE INTERRUEM AULA
-- Fonte: https://dados.inmet.gov.br/alertas/cap12
-- Granularidade: evento com código IBGE no payload
-- Mede o EVENTO que interrompe a aula (não exposição)
-- =================================================================

DROP TABLE IF EXISTS clean.inmet_alerta;
CREATE TABLE clean.inmet_alerta (
    id_alerta           BIGINT NOT NULL,       -- ID único do alerta
    codigo_ibge         TEXT NOT NULL,         -- 7 dígitos IBGE do município afetado
    uf                  CHAR(2) NOT NULL,      -- UF
    data_inicio         TIMESTAMPTZ NOT NULL,  -- início do evento
    data_fim            TIMESTAMPTZ,           -- fim do evento (pode ser nulo se em andamento)
    severidade          TEXT,                  -- ex.: 'Moderado', 'Severo', 'Extremo'
    descricao           TEXT,                  -- descrição do fenômeno
    risco               TEXT,                  -- risco associado
    instrucao           TEXT,                  -- instruções para a população
    -- Metadados
    dt_criacao          TIMESTAMPTZ DEFAULT NOW(),
    dt_atualizacao      TIMESTAMPTZ,

    CONSTRAINT pk_inmet_alerta PRIMARY KEY (id_alerta)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_inmet_alerta_codigo_ibge ON clean.inmet_alerta (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_inmet_alerta_data_inicio ON clean.inmet_alerta (data_inicio);
CREATE INDEX IF NOT EXISTS idx_inmet_alerta_severidade ON clean.inmet_alerta (severidade);
CREATE INDEX IF NOT EXISTS idx_inmet_alerta_uf ON clean.inmet_alerta (uf);

-- FK para malha_municipio
ALTER TABLE clean.inmet_alerta
  ADD CONSTRAINT fk_inmet_alerta_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.inmet_alerta IS 'INMET Alerta-AS (CAP 1.2) - eventos meteorológicos que interrompem aula. Cada linha é um evento com código IBGE do município afetado. Mede o EVENTO, não a exposição.';
COMMENT ON COLUMN clean.inmet_alerta.id_alerta IS 'ID único do alerta (chave primária)';
COMMENT ON COLUMN clean.inmet_alerta.codigo_ibge IS 'Código IBGE do município afetado (7 dígitos)';
COMMENT ON COLUMN clean.inmet_alerta.uf IS 'UF do município';
COMMENT ON COLUMN clean.inmet_alerta.data_inicio IS 'Data/hora de início do evento meteorológico';
COMMENT ON COLUMN clean.inmet_alerta.data_fim IS 'Data/hora de fim do evento (NULL se em andamento)';
COMMENT ON COLUMN clean.inmet_alerta.severidade IS 'Severidade: Moderado, Severo, Extremo';
COMMENT ON COLUMN clean.inmet_alerta.descricao IS 'Descrição do fenômeno meteorológico';
COMMENT ON COLUMN clean.inmet_alerta.risco IS 'Risco associado ao evento';
COMMENT ON COLUMN clean.inmet_alerta.instrucao IS 'Instruções para a população';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.inmet_alerta'::text,
       'API INMET Alerta-AS (CAP 1.2)'::text,
       'https://dados.inmet.gov.br/alertas/cap12'::text,
       'CC-BY-4.0 (INMET)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: inmet_alerta. Mede EVENTO que interrompe aula, não exposição.'
FROM clean.inmet_alerta;

COMMIT;