-- Revert edumaps:auth_falhas_telegram from pg

BEGIN;

DELETE FROM clean.auth_falhas WHERE escopo = 'telegram';
ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip', 'reset_email', 'reset_ip', 'canais'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email/ip: falha de login; cadastro_ip: tentativa de cadastro; reset_email/reset_ip: redefinição de senha; canais: pedido às rotas públicas das listas com QR (por token+IP).';

COMMIT;
