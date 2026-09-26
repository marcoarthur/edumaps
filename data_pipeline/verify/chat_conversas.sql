-- verify chat_conversas

SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean' AND table_name = 'chat_conversas';

SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean' AND table_name = 'chat_mensagens';

-- índices
SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean' AND indexname = 'idx_chat_conversas_gestor_created';

SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean' AND indexname = 'idx_chat_conversas_titulo_gin';

SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean' AND indexname = 'idx_chat_mensagens_conversa';

SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean' AND indexname = 'idx_chat_mensagens_content_gin';

-- trigger updated_at
SELECT 1
FROM information_schema.triggers
WHERE trigger_schema = 'clean' AND event_object_table = 'chat_conversas' AND trigger_name = 'tg_chat_conversas_updated_at';

-- FKs
SELECT 1
FROM information_schema.table_constraints
WHERE constraint_schema = 'clean' AND table_name = 'chat_conversas' AND constraint_type = 'FOREIGN KEY';

SELECT 1
FROM information_schema.table_constraints
WHERE constraint_schema = 'clean' AND table_name = 'chat_mensagens' AND constraint_type = 'FOREIGN KEY';