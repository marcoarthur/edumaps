-- Deploy edumaps:auth_falhas to pg
-- requires: gestor_respostas

-- #335: limite de tentativas de login e de cadastro do gestor.
-- Uma linha por tentativa que conta para o limite. A contagem vive no banco
-- (e não na memória do processo) para valer com vários workers e sobreviver
-- a reinícios. `chave` é HMAC (segredo da aplicação) do e-mail em minúsculas
-- ou do IP: a tabela não guarda dado pessoal legível (LGPD).

BEGIN;

CREATE TABLE clean.auth_falhas (
  id        bigserial   PRIMARY KEY,
  escopo    text        NOT NULL CHECK (escopo IN ('email', 'ip', 'cadastro_ip')),
  chave     text        NOT NULL CHECK (chave ~ '^[0-9a-f]{64}$'),
  criado_em timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX auth_falhas_escopo_chave_idx ON clean.auth_falhas (escopo, chave, criado_em DESC);
CREATE INDEX auth_falhas_criado_em_idx    ON clean.auth_falhas (criado_em);

COMMENT ON TABLE clean.auth_falhas IS
  'Tentativas que contam para o limite de login/cadastro do gestor (#335). Linhas antigas são apagadas pelo backend a cada registro.';
COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email: falha de login por e-mail; ip: falha de login por IP; cadastro_ip: tentativa de cadastro por IP.';
COMMENT ON COLUMN clean.auth_falhas.chave IS
  'HMAC-SHA256 (segredo da aplicação) do e-mail em minúsculas ou do IP — nunca o valor em claro.';

COMMIT;
