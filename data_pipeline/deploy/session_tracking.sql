-- Deploy edumaps:session_tracking to pg

BEGIN;

CREATE TABLE session_tracking (
    session_id    TEXT PRIMARY KEY,
    ip            INET,
    ip_anon       TEXT,
    user_agent    TEXT,
    is_logged     BOOLEAN DEFAULT FALSE,
    gestor_id     BIGINT,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    seen_count    BIGINT NOT NULL DEFAULT 1
);

CREATE INDEX idx_session_tracking_last_seen ON session_tracking (last_seen_at);

COMMENT ON TABLE session_tracking IS 'Sessões de visitantes/usuários (telemetria): IP + identidade + atividade agregada';
COMMENT ON COLUMN session_tracking.ip IS 'IP cru do visitante — retenção curta (privacy.ip_retention_days); nunca em event_store';
COMMENT ON COLUMN session_tracking.ip_anon IS 'HMAC(ip + salt diário) para análise sem dado pessoal (privacy.anon_salt)';
COMMENT ON COLUMN session_tracking.is_logged IS 'Se a sessão pertence a um gestor logado (gestor_id preenchido)';
COMMENT ON COLUMN session_tracking.seen_count IS 'Nº de interações (eventos) registradas para a sessão';

COMMIT;