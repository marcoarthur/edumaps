-- Deploy edumaps:school_embedding_l2 to pg
-- requires: school_embedding

-- #487 (RL-01): as escolas semelhantes do painel passam do cosseno para a
-- distância euclidiana entre as seis notas. O cosseno mede o ângulo entre os
-- vetores e ignora o nível: (2,2,2,2,2,2) e (8,8,8,8,8,8) ficavam idênticos.
-- Os vetores gravados não mudam; muda só a operação do índice ANN.

BEGIN;

  DROP INDEX analytics.idx_school_embedding_hnsw;

  CREATE INDEX idx_school_embedding_hnsw
    ON analytics.school_embedding
    USING hnsw (embedding vector_l2_ops);

  COMMENT ON TABLE analytics.school_embedding IS
    'Embedding (6 notas de clean.mv_escolas_scores, de 0 a 10) de cada escola para a busca de escolas semelhantes pela distância euclidiana entre as notas (pgvector <->, #487). Escola com alguma nota nula fica fora (#413).';

  COMMENT ON INDEX analytics.idx_school_embedding_hnsw IS
    'HNSW com vector_l2_ops: vizinhas pela distância euclidiana entre as notas (#487).';

COMMIT;
