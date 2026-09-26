-- revert chat_conversas

BEGIN;

DROP TRIGGER IF EXISTS tg_chat_conversas_updated_at ON clean.chat_conversas;
DROP FUNCTION IF EXISTS clean.tg_chat_conversas_updated_at();

DROP TABLE IF EXISTS clean.chat_mensagens;
DROP TABLE IF EXISTS clean.chat_conversas;

COMMIT;