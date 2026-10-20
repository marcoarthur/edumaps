-- Verify edumaps:analytics_ivet_escola on pg

BEGIN;

  -- Confirma que a tabela e todas as colunas esperadas existem.
  -- (falha com "relation/column does not exist" se algo estiver faltando)
  SELECT co_entidade, nu_ano_censo, raio_m, ivet, publicavel,
         bloco_a, bloco_b, bloco_c, bloco_d, bloco_e, bloco_f, bloco_g,
         formula, dataset_version, transform_version,
         dt_snapshot, calculado_em
  FROM analytics.ivet_escola
  WHERE FALSE;

  -- Confirma a primary key nomeada (deve FALHAR com division by zero
  -- quando ausente — regra do gate de verify, issue #160).
  SELECT 1 / COUNT(*) FROM pg_constraint
  WHERE conrelid = 'analytics.ivet_escola'::regclass
    AND contype  = 'p'
    AND conname  = 'pk_ivet_escola';

  -- Confirma o índice de snapshot (consultas administrativas).
  SELECT 1 / COUNT(*) FROM pg_indexes
  WHERE schemaname = 'analytics'
    AND tablename   = 'ivet_escola'
    AND indexname   = 'idx_ivet_escola_dt_snapshot';

COMMIT;
