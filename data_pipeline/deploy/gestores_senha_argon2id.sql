-- Deploy edumaps:gestores_senha_argon2id to pg
-- requires: gestor_respostas

-- #334: a senha do gestor passa a Argon2id. Só documentação da coluna: os
-- hashes antigos (HMAC-SHA256) são regravados pelo backend no próximo login
-- certo, sem migração de dados (o banco não conhece as senhas).

BEGIN;

COMMENT ON COLUMN clean.gestores.senha_hash IS
  'Hash Argon2id no formato padrão ($argon2id$v=19$m=…,t=…,p=…$sal$hash) — ver Roles::Business::Pesquisa::Gestores. Formato antigo "<sal_hex>:<hmac_sha256_hex>" ainda aceito e regravado em Argon2id no próximo login. NULL só para gestores legados (sem login ainda).';

COMMIT;
