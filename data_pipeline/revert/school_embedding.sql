-- Revert edumaps:school_embedding from pg

BEGIN;

  -- Remove a tabela (o índice HNSW cai junto). A extensão `vector` NÃO é
  -- removida aqui de propósito: ela pode ser compartilhada por outros
  -- objetos/migrations; remova-a manualmente se não houver mais uso.
  DROP TABLE IF EXISTS analytics.school_embedding;

COMMIT;
