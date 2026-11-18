-- Revert edumaps:school_embedding_l2 from pg

BEGIN;

  DROP INDEX analytics.idx_school_embedding_hnsw;

  CREATE INDEX idx_school_embedding_hnsw
    ON analytics.school_embedding
    USING hnsw (embedding vector_cosine_ops);

  COMMENT ON TABLE analytics.school_embedding IS
    'Embedding (6 scores) de cada escola para busca de similaridade por cosseno (pgvector). Fonte: clean.mv_escolas_scores.';

COMMIT;
