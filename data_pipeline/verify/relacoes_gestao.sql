-- Verify edumaps:relacoes_gestao from pg

BEGIN;

  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN (
      'relacoes_interacoes',
      'relacoes_documentos'
    );

  -- FKs para relacoes com ON DELETE CASCADE.
  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace
      AND conrelid IN (
        'clean.relacoes_interacoes'::regclass,
        'clean.relacoes_documentos'::regclass
      )
      AND confrelid = 'clean.relacoes'::regclass
      AND confdeltype = 'c';

  SELECT 1/COUNT(*) FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname IN (
      'idx_relacoes_interacoes_relacao',
      'idx_relacoes_documentos_relacao'
    );

COMMIT;
