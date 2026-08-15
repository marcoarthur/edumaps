-- Verify edumaps:event_store on pg

BEGIN;

  -- 1. Verifica se a tabela e todas as colunas existem
  SELECT id,
         event_id,
         event_type,
         codigo_ibge,
         is_speculative,
         source,
         payload,
         created_at
    FROM event_store
   WHERE false;

  -- 2. Verifica a existência dos índices (falha com divisão por zero caso o índice não exista)
  SELECT 1/COUNT(*) FROM pg_indexes WHERE indexname = 'idx_event_store_type_ibge';
  SELECT 1/COUNT(*) FROM pg_indexes WHERE indexname = 'idx_event_store_created_at';

COMMIT;
