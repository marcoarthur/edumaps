-- Revert edumaps:gestor_senha_redefinicao from pg

BEGIN;

DROP TABLE IF EXISTS clean.senha_redefinicoes;

DELETE FROM clean.auth_falhas WHERE escopo IN ('reset_email', 'reset_ip');
ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email: falha de login por e-mail; ip: falha de login por IP; cadastro_ip: tentativa de cadastro por IP.';

COMMIT;
