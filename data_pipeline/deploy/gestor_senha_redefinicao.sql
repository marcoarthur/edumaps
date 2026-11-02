-- Deploy edumaps:gestor_senha_redefinicao to pg
-- requires: auth_falhas

-- #336: "esqueci minha senha" do gestor.
-- Um pedido gera um token aleatório de uso único, enviado por e-mail; o banco
-- guarda só o SHA-256 dele. Vale 30 min (expira_em) e um pedido novo invalida
-- os anteriores (usado_em). Os limites de pedido usam clean.auth_falhas com
-- dois escopos novos.

BEGIN;

CREATE TABLE clean.senha_redefinicoes (
  id         bigserial   PRIMARY KEY,
  gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
  token_hash text        NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  criado_em  timestamptz NOT NULL DEFAULT now(),
  expira_em  timestamptz NOT NULL,
  usado_em   timestamptz
);

CREATE INDEX senha_redefinicoes_gestor_idx ON clean.senha_redefinicoes (gestor_id) WHERE usado_em IS NULL;

COMMENT ON TABLE clean.senha_redefinicoes IS
  'Pedidos de redefinição de senha do gestor (#336). Só o hash do token; uso único; validade curta.';
COMMENT ON COLUMN clean.senha_redefinicoes.token_hash IS
  'SHA-256 (hex) do token enviado por e-mail — o token em claro nunca é gravado.';
COMMENT ON COLUMN clean.senha_redefinicoes.usado_em IS
  'Quando o token foi usado ou invalidado (pedido mais novo). NULL = ainda válido até expira_em.';

ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip', 'reset_email', 'reset_ip'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email/ip: falha de login; cadastro_ip: tentativa de cadastro; reset_email/reset_ip: pedido ou uso de redefinição de senha.';

COMMIT;
