-- Deploy edumaps:school_embedding to pg

BEGIN;

  -- Extensão pgvector: tipo `vector` + operador de distância de cosseno `<=>`.
  CREATE EXTENSION IF NOT EXISTS vector;

  -- Um vetor de 6 dimensões por escola, derivado de clean.mv_escolas_scores.
  -- A ordem dos scores define o espaço vetorial; a similaridade é por cosseno
  -- (independe da escala/magnitude absoluta dos scores).
  CREATE TABLE analytics.school_embedding (
    co_entidade bigint PRIMARY KEY,
    embedding   vector(6) NOT NULL
  );

  COMMENT ON TABLE analytics.school_embedding IS
    'Embedding (6 scores) de cada escola para busca de similaridade por cosseno (pgvector). Fonte: clean.mv_escolas_scores.';

  -- Backfill a partir dos scores consolidados (mesma ordem de dimensões).
  INSERT INTO analytics.school_embedding (co_entidade, embedding)
  SELECT
    co_entidade,
    ARRAY[
      COALESCE(score_capacidade_atendimento, 0),
      COALESCE(score_infraestrutura, 0),
      COALESCE(score_capacitacao_docente, 0),
      COALESCE(score_diversidade_discente, 0),
      COALESCE(score_capacidade_gestora, 0),
      COALESCE(score_sustentabilidade, 0)
    ]::vector
  FROM clean.mv_escolas_scores
  ON CONFLICT (co_entidade) DO NOTHING;

  -- Índice ANN (HNSW) para cosseno: busca top-k aproximada em milissegundos.
  CREATE INDEX idx_school_embedding_hnsw
    ON analytics.school_embedding
    USING hnsw (embedding vector_cosine_ops);

COMMIT;
