-- Deploy edumaps:sessoes_token_hash to pg
-- requires: auth_falhas_canais
--
-- Sessão do gestor: o banco guarda só o SHA-256 do token (hex), nunca o
-- token. O backend recebe o bearer, calcula o hash e busca por ele. Os tokens
-- já existentes são convertidos no lugar, então ninguém precisa entrar de novo.

BEGIN;

  UPDATE clean.sessoes
     SET token = encode(sha256(convert_to(token, 'UTF8')), 'hex');

  ALTER TABLE clean.sessoes RENAME COLUMN token TO token_hash;
  ALTER TABLE clean.sessoes RENAME CONSTRAINT sessoes_token_key TO sessoes_token_hash_key;

  ALTER TABLE clean.sessoes
    ADD CONSTRAINT sessoes_token_hash_formato CHECK (token_hash ~ '^[0-9a-f]{64}$');

  COMMENT ON TABLE clean.sessoes IS
    'Sessões de login do gestor. Guarda só o SHA-256 do token bearer (token_hash); validação por existência + expiração.';
  COMMENT ON COLUMN clean.sessoes.token_hash IS
    'SHA-256 (hex) do token bearer. O token em claro só existe no cliente.';

COMMIT;
