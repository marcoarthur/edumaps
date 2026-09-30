-- Deploy edumaps:import_metadata_fase0 to pg
-- requires: schemas

BEGIN;

-- =================================================================
-- FASE 0: Proveniência com licença em clean.import_metadata
-- =================================================================

-- Adicionar colunas de proveniência
ALTER TABLE clean.import_metadata
    ADD COLUMN IF NOT EXISTS source_url TEXT,
    ADD COLUMN IF NOT EXISTS source_license TEXT,
    ADD COLUMN IF NOT EXISTS retrieved_at TIMESTAMPTZ;

-- Comentários
COMMENT ON COLUMN clean.import_metadata.source_url IS
'URL canônica exata do recurso baixado (ex.: https://www.fnde.gov.br/.../consultarRemuneracaoMunicipal.do)';

COMMENT ON COLUMN clean.import_metadata.source_license IS
'Identificador SPDX da licença da fonte (ex.: CC-BY-4.0, ODbL-1.0, CC0-1.0, "Não verificada")';

COMMENT ON COLUMN clean.import_metadata.retrieved_at IS
'Timestamp de quando o arquivo/recurso foi baixado do endpoint';

-- Índice para consultas por URL
CREATE INDEX IF NOT EXISTS idx_import_metadata_source_url
    ON clean.import_metadata (source_url);

COMMIT;