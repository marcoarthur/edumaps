-- Verify edumaps:relacoes_escolar from pg

BEGIN;

  -- As três tabelas precisam existir.
  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN (
      'relacoes_categorias',
      'relacoes_entidades',
      'relacoes'
    );

  -- CHECKs de eixo/origem/status/prioridade.
  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace AND conname IN (
      'relacoes_categorias_eixo_check',
      'relacoes_categorias_origem_check',
      'relacoes_status_check',
      'relacoes_prioridade_check'
    );

  -- Índices únicos e FK RESTRICT entidade -> relações.
  SELECT 1/COUNT(*) FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname IN (
      'uq_relacoes_categorias_inep_eixo_nome',
      'uq_relacoes_entidades_inep_nome'
    );

  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace
      AND conrelid = 'clean.relacoes'::regclass
      AND confrelid = 'clean.relacoes_entidades'::regclass
      AND confdeltype = 'r';

COMMIT;
