-- Deploy edumaps:auth_falhas_telegram to pg
-- requires: leitor_sem_tabelas_sensiveis

-- Limitador do bot público do Telegram. Antes: em memória, por processo
-- (cada worker do webhook e o minion do polling contavam à parte, e a
-- contagem zerava a cada reinício). Agora usa clean.auth_falhas com o escopo
-- `telegram` (chave = HMAC do chat_id).

BEGIN;

ALTER TABLE clean.auth_falhas DROP CONSTRAINT auth_falhas_escopo_check;
ALTER TABLE clean.auth_falhas ADD CONSTRAINT auth_falhas_escopo_check
  CHECK (escopo IN ('email', 'ip', 'cadastro_ip', 'reset_email', 'reset_ip', 'canais', 'telegram'));

COMMENT ON COLUMN clean.auth_falhas.escopo IS
  'email/ip: falha de login; cadastro_ip: tentativa de cadastro; reset_email/reset_ip: redefinição de senha; canais: pedido às rotas públicas das listas com QR (por token+IP); telegram: mensagem recebida pelo bot público (por conversa).';

COMMIT;
