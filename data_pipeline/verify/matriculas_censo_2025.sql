-- Verify edumaps:matriculas_censo_2025 on pg

BEGIN;

  -- Verifica se a tabela existe
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name = 'censo_matriculas';

  -- Verifica se uma coluna chave existe (ex: nu_ano_censo)
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name = 'censo_matriculas'
    AND column_name = 'nu_ano_censo';

  -- Verifica se a primary key foi criada
  SELECT 1
  FROM pg_constraint
  WHERE conname = 'censo_matriculas_pkey'
    AND conrelid = 'clean.censo_matriculas'::regclass;

ROLLBACK;
