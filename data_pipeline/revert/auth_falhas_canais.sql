-- Revert edumaps:auth_falhas_canais from pg

BEGIN;

DELETE FROM clean.auth_falhas WHERE escopo = 'canais';
ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip', 'reset_email', 'reset_ip'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email/ip: falha de login; cadastro_ip: tentativa de cadastro; reset_email/reset_ip: pedido ou uso de redefinição de senha.';

COMMIT;
