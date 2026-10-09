-- verify chat_conversas
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- tabelas
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN ('chat_conversas', 'chat_mensagens');
    IF n <> 2 THEN
        RAISE EXCEPTION 'chat_conversas: esperava clean.chat_conversas e clean.chat_mensagens, encontrei %', n;
    END IF;

    -- índices
    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname IN (
        'idx_chat_conversas_gestor_created', 'idx_chat_conversas_titulo_gin',
        'idx_chat_mensagens_conversa', 'idx_chat_mensagens_content_gin');
    IF n <> 4 THEN
        RAISE EXCEPTION 'chat_conversas: esperava 4 índices, encontrei %', n;
    END IF;

    -- trigger updated_at
    SELECT count(*) INTO n
    FROM information_schema.triggers
    WHERE trigger_schema = 'clean' AND event_object_table = 'chat_conversas'
      AND trigger_name = 'tg_chat_conversas_updated_at';
    IF n < 1 THEN
        RAISE EXCEPTION 'chat_conversas: trigger tg_chat_conversas_updated_at ausente';
    END IF;

    -- FKs
    SELECT count(*) INTO n
    FROM information_schema.table_constraints
    WHERE constraint_schema = 'clean'
      AND table_name IN ('chat_conversas', 'chat_mensagens')
      AND constraint_type = 'FOREIGN KEY';
    IF n < 2 THEN
        RAISE EXCEPTION 'chat_conversas: esperava FKs em chat_conversas e chat_mensagens, encontrei %', n;
    END IF;
END $$;

ROLLBACK;
