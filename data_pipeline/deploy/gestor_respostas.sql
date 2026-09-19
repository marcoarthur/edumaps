-- Deploy edumaps:gestor_respostas to pg
-- requires: gestor_pesquisas
--
-- Fase 2 das pesquisas do gestor: coleta de respostas da comunidade,
-- resultados e login do gestor.
--   - gestor_pesquisas.token: UUID público para o link de resposta (impede
--     enumeração por id numérico).
--   - gestores.senha_hash: hash (HMAC-SHA256 + salt) para o login do gestor.
--   - clean.sessoes: tokens de sessão (bearer) do gestor.
--   - answers: gestor_pesquisas_respostas (+ _itens) com bloqueio por
--     dispositivo (UNIQUE pesquisa × identificador_dispositivo).

BEGIN;

  -- Link público de resposta: token aleatório por pesquisa.
  ALTER TABLE clean.gestor_pesquisas
    ADD COLUMN token uuid NOT NULL DEFAULT gen_random_uuid();

  ALTER TABLE clean.gestor_pesquisas
    ADD CONSTRAINT uq_gestor_pesquisas_token UNIQUE (token);

  COMMENT ON COLUMN clean.gestor_pesquisas.token IS
    'UUID público do link de resposta (fase 2). Nunca usado como PK — evita enumerar pesquisas por id numérico.';

  -- Senha do gestor para login (nunca armazenada em claro).
  ALTER TABLE clean.gestores
    ADD COLUMN senha_hash text;

  COMMENT ON COLUMN clean.gestores.senha_hash IS
    'Hash HMAC-SHA256(senha, salt por gestor) no formato hex — ver Roles::Business::Pesquisa::Gestores. NULL só para gestores legados (sem login ainda).';

  -- Sessões do gestor (login). Token bearer aleatório; expira após o prazo.
  CREATE TABLE clean.sessoes (
    id         bigserial   PRIMARY KEY,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    token      text        NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    expires_at timestamptz NOT NULL
  );

  COMMENT ON TABLE clean.sessoes IS
    'Sessões de login do gestor. Token bearer (uuid) — validação por existência + expiração.';

  CREATE INDEX idx_sessoes_gestor ON clean.sessoes (gestor_id);
  CREATE INDEX idx_sessoes_expires ON clean.sessoes (expires_at);

  -- Respostas da comunidade: uma por dispositivo (bloqueio leve via UUID anônimo).
  CREATE TABLE clean.gestor_pesquisas_respostas (
    id                          bigserial   PRIMARY KEY,
    pesquisa_id                 bigint      NOT NULL REFERENCES clean.gestor_pesquisas (id) ON DELETE CASCADE,
    identificador_dispositivo   text        NOT NULL,
    respondida_em               timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (pesquisa_id, identificador_dispositivo)
  );

  COMMENT ON TABLE clean.gestor_pesquisas_respostas IS
    'Respostas completas da comunidade a uma pesquisa publicada. Sem PII — o autor é um UUID anônimo de dispositivo.';
  COMMENT ON COLUMN clean.gestor_pesquisas_respostas.identificador_dispositivo IS
    'UUID anônimo gerado no navegador do respondente (localStorage). UNIQUE por pesquisa bloqueia resposta duplicada do mesmo dispositivo.';

  CREATE INDEX idx_respostas_pesquisa ON clean.gestor_pesquisas_respostas (pesquisa_id);

  -- Itens: uma linha por opção escolhida (unica/multipla/dropdown) ou texto livre.
  CREATE TABLE clean.gestor_pesquisas_respostas_itens (
    id           bigserial PRIMARY KEY,
    resposta_id  bigint    NOT NULL REFERENCES clean.gestor_pesquisas_respostas (id) ON DELETE CASCADE,
    pergunta_id  bigint    NOT NULL REFERENCES clean.gestor_pesquisas_perguntas (id) ON DELETE CASCADE,
    opcao_id     text,
    valor_texto  text
  );

  COMMENT ON TABLE clean.gestor_pesquisas_respostas_itens IS
    'Resposta a uma pergunta específica. opcao_id guarda o id da opção escolhida (referencia o JSONB de gestor_pesquisas_perguntas.opcoes); valor_texto para perguntas livres.';

  CREATE INDEX idx_respostas_itens_resposta  ON clean.gestor_pesquisas_respostas_itens (resposta_id);
  CREATE INDEX idx_respostas_itens_pergunta  ON clean.gestor_pesquisas_respostas_itens (pergunta_id);

COMMIT;