-- Verify edumaps:ranking_escola on pg

BEGIN;

  -- Confirma que a tabela e todas as colunas esperadas existem.
  -- (falha com "relation/column does not exist" se algo estiver faltando)
  SELECT indicador_id, rede, id_escola, ano, valor,
         rank_municipio, total_municipio,
         rank_estado, total_estado,
         rank_nacional, total_nacional,
         data_atualizacao
  FROM analytics.ranking_escola
  WHERE FALSE;

  -- Confirma a primary key nomeada.
  SELECT 1 / COUNT(*) FROM pg_constraint
  WHERE conrelid = 'analytics.ranking_escola'::regclass
    AND contype  = 'p'
    AND conname  = 'pk_ranking_escola';

  -- Confirma os índices de apoio às consultas de leaderboard e de auditoria.
  SELECT 1 / COUNT(*) FROM pg_indexes
  WHERE schemaname = 'analytics'
    AND tablename   = 'ranking_escola'
    AND indexname   = 'idx_ranking_escola_rank_nacional';

  SELECT 1 / COUNT(*) FROM pg_indexes
  WHERE schemaname = 'analytics'
    AND tablename   = 'ranking_escola'
    AND indexname   = 'idx_ranking_escola_ano';

  -- Confirma o CHECK de domínio da coluna 'rede'.
  SELECT 1 / COUNT(*) FROM pg_constraint
  WHERE conrelid = 'analytics.ranking_escola'::regclass
    AND contype  = 'c'
    AND conname  = 'ck_ranking_escola_rede';

ROLLBACK;
