-- Verify edumaps:relacoes_tarefas from pg

BEGIN;

  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'relacoes_tarefas';

  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace
      AND conrelid = 'clean.relacoes_tarefas'::regclass
      AND confrelid = 'clean.relacoes'::regclass
      AND confdeltype = 'c';

  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace AND conname = 'relacoes_tarefas_status_check';

  SELECT 1/COUNT(*) FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname IN (
      'idx_relacoes_tarefas_relacao',
      'idx_relacoes_tarefas_status'
    );

COMMIT;
