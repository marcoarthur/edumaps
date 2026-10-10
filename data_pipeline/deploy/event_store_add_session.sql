-- Deploy edumaps:event_store_add_session to pg

BEGIN;

ALTER TABLE event_store ADD COLUMN session_id TEXT;
ALTER TABLE event_store ADD COLUMN gestor_id BIGINT;

CREATE INDEX idx_event_store_session_created ON event_store (session_id, created_at);

COMMENT ON COLUMN event_store.session_id IS 'Sessão do visitante que gerou o evento (session_tracking.session_id); nulo = evento interno';
COMMENT ON COLUMN event_store.gestor_id IS 'Gestor logado que gerou o evento (clean.gestores.id), quando houver';

COMMIT;