-- Revert edumaps:canal_confirmacao_listas from pg
--
-- Ordem inversa: tabelas novas (refs referencia inscrições e membros) e depois
-- as colunas acrescentadas às tabelas da Fase 0. IF EXISTS: reverter num banco
-- parcialmente aplicado não aborta o restante.

BEGIN;

  DROP TABLE IF EXISTS clean.canal_telegram_estado;
  DROP TABLE IF EXISTS clean.canal_confirmacao_refs;

  ALTER TABLE clean.canal_lista_membros
    DROP COLUMN IF EXISTS telegram_chat_id,
    DROP COLUMN IF EXISTS confirmado_via,
    DROP COLUMN IF EXISTS confirmado_em;

  ALTER TABLE clean.canal_listas
    DROP COLUMN IF EXISTS exige_confirmacao;

COMMIT;
