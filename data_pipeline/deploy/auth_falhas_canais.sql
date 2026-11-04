-- Deploy edumaps:auth_falhas_canais to pg
-- requires: gestor_senha_redefinicao

-- Limitador das rotas públicas das listas com QR (inscrição, confirmação,
-- exclusão, saída). Antes: em memória, por processo, e com o IP do nginx —
-- todos os visitantes dividiam a contagem. Agora usa clean.auth_falhas com o
-- escopo `canais` (chave = HMAC de "token|IP real").

BEGIN;

ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip', 'reset_email', 'reset_ip', 'canais'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email/ip: falha de login; cadastro_ip: tentativa de cadastro; reset_email/reset_ip: redefinição de senha; canais: pedido às rotas públicas das listas com QR (por token+IP).';

COMMIT;
