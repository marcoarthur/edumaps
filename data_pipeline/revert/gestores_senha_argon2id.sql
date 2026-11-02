-- Revert edumaps:gestores_senha_argon2id from pg

BEGIN;

COMMENT ON COLUMN clean.gestores.senha_hash IS
  'Hash HMAC-SHA256(senha, salt por gestor) no formato hex — ver Roles::Business::Pesquisa::Gestores. NULL só para gestores legados (sem login ainda).';

COMMIT;
