-- Verify edumaps:school_embedding on pg

BEGIN;

  -- A tabela de embeddings existe
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'analytics' AND table_name = 'school_embedding'
  ) AS table_exists;

  -- A extensão pgvector está instalada
  SELECT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'vector'
  ) AS vector_installed;

  -- O índice HNSW está presente
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'analytics'
      AND tablename = 'school_embedding'
      AND indexname = 'idx_school_embedding_hnsw'
  ) AS hnsw_index_exists;

ROLLBACK;
