-- Deploy edumaps:app_config to pg
-- requires: schemas
--
-- Configuração global do EduMaps (painel administrativo). Uma chave-por-item
-- (key), com suporte a valores não sensíveis (jsonb) e segredos cifrados com
-- pgcrypto pgp_sym_encrypt (OpenPGP simétrico: nonce + MAC embutidos no
-- ciphertext). A master key vive fora do banco, em env do backend
-- (EDUMAPS_CONFIG_MASTER_KEY); o descritor secret_key_version permite
-- rotação futura da chave.
--
-- O schema app_config NÃO é concedido à role edumaps_leitor (somente-leitura
-- p/ o assistente NL/SQL): o R lê configuração via payload do backend, não do
-- banco.

BEGIN;

  CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;

  CREATE SCHEMA IF NOT EXISTS app_config;

  CREATE TABLE app_config.items (
    key                text        PRIMARY KEY,
    value              jsonb,
    secret             bytea,
    secret_key_version integer     NOT NULL DEFAULT 1,
    sensitive          boolean     NOT NULL DEFAULT FALSE,
    updated_by         text,
    updated_at         timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE app_config.items IS
    'Configuração global do EduMaps, administrada pelo Painel de Configuração. key é o caminho (ex.: integrations.assistant_censo.api_key). Segredos (sensitive=TRUE) são guardados cifrados (pgp_sym_encrypt) com master key do ambiente do backend; value jsonb para valores não sensíveis.';
  COMMENT ON COLUMN app_config.items.key IS
    'Caminho da config (ex.: integrations.assistant_censo.api_key). Único.';
  COMMENT ON COLUMN app_config.items.value IS
    'Valor jsonb para configurações não sensíveis (ex.: nome da instalação, fuso).';
  COMMENT ON COLUMN app_config.items.secret IS
    'Ciphertext do segredo (pgp_sym_encrypt). Nunca exposto pela API.';
  COMMENT ON COLUMN app_config.items.secret_key_version IS
    'Versão da master key usada na cifragem — permite rotação sem reescrever histórico.';
  COMMENT ON COLUMN app_config.items.sensitive IS
    'TRUE para itens secretos (guardados cifrados e sempre mascarados na API).';
  COMMENT ON COLUMN app_config.items.updated_by IS
    'Identificação de quem alterou (email/nome do admin autenticado).';
  COMMENT ON COLUMN app_config.items.updated_at IS
    'Momento da última alteração.';

COMMIT;