-- chat_conversas: histórico de conversas do Assistente do Censo
-- Requer: gestor_pesquisas (clean.gestores)

BEGIN;

CREATE TABLE clean.chat_conversas (
    id              bigserial PRIMARY KEY,
    gestor_id       bigint NOT NULL REFERENCES clean.gestores(id) ON DELETE CASCADE,
    titulo          text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE clean.chat_mensagens (
    id              bigserial PRIMARY KEY,
    conversa_id     bigint NOT NULL REFERENCES clean.chat_conversas(id) ON DELETE CASCADE,
    role            text NOT NULL CHECK (role IN ('user', 'assistant')),
    content         text NOT NULL,
    meta            jsonb,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- Índices para listagem e busca
CREATE INDEX idx_chat_conversas_gestor_created ON clean.chat_conversas (gestor_id, created_at DESC);
CREATE INDEX idx_chat_conversas_titulo_gin ON clean.chat_conversas USING gin (to_tsvector('portuguese', coalesce(titulo, '')));
CREATE INDEX idx_chat_mensagens_conversa ON clean.chat_mensagens (conversa_id, created_at);
CREATE INDEX idx_chat_mensagens_content_gin ON clean.chat_mensagens USING gin (to_tsvector('portuguese', content));

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION clean.tg_chat_conversas_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_chat_conversas_updated_at
BEFORE UPDATE ON clean.chat_conversas
FOR EACH ROW EXECUTE FUNCTION clean.tg_chat_conversas_updated_at();

COMMENT ON TABLE clean.chat_conversas IS 'Conversas salvas do Assistente do Censo (gestor -> perguntas/respostas)';
COMMENT ON TABLE clean.chat_mensagens IS 'Mensagens individuais (pergunta ou resposta) de uma conversa salva';
COMMENT ON COLUMN clean.chat_conversas.titulo IS 'Título opcional dado pelo gestor para busca/exibição';
COMMENT ON COLUMN clean.chat_mensagens.role IS 'Papel da mensagem: user (pergunta) ou assistant (resposta)';
COMMENT ON COLUMN clean.chat_mensagens.meta IS 'Metadados JSON: sql, resultado, origem, linhas, colunas, timestamp';

COMMIT;