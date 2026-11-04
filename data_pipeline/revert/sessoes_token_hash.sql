-- Revert edumaps:sessoes_token_hash from pg
-- O token original não é recuperável a partir do hash: as sessões são
-- apagadas (todos entram de novo).

BEGIN;

  DELETE FROM clean.sessoes;
  ALTER TABLE clean.sessoes DROP CONSTRAINT sessoes_token_hash_formato;
  ALTER TABLE clean.sessoes RENAME CONSTRAINT sessoes_token_hash_key TO sessoes_token_key;
  ALTER TABLE clean.sessoes RENAME COLUMN token_hash TO token;
  COMMENT ON COLUMN clean.sessoes.token IS NULL;
  COMMENT ON TABLE clean.sessoes IS
    'Sessões de login do gestor. Token bearer (uuid) — validação por existência + expiração.';

COMMIT;
