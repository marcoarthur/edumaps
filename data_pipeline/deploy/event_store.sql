-- Deploy edumaps:event_store to pg

BEGIN;

CREATE TABLE event_store (
    id             BIGSERIAL PRIMARY KEY,
    event_id       VARCHAR(64) NOT NULL,
    event_type     VARCHAR(100) NOT NULL,
    codigo_ibge    VARCHAR(7),
    is_speculative BOOLEAN DEFAULT FALSE,
    source         VARCHAR(150),
    payload        JSONB,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para buscas rápidas e agregação de métricas
CREATE INDEX idx_event_store_type_ibge ON event_store (event_type, codigo_ibge);
CREATE INDEX idx_event_store_created_at ON event_store (created_at);

-- Documentação de colunas chave
COMMENT ON TABLE event_store IS 'Armazena a telemetria e histórico de eventos disparados no EventBus';
COMMENT ON COLUMN event_store.is_speculative IS 'Flag que identifica se o evento foi disparado via pré-computação especulativa';

COMMIT;
