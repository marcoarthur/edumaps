-- Verify edumaps:dados_ibge on pg

BEGIN;

  -- Tabela existe?
  SELECT 1
  FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name = 'dados_ibge';

  -- Colunas críticas existem?
  SELECT column_name
  FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name = 'dados_ibge'
    AND column_name IN ('codigo_ibge', 'ano', 'pib_total');

  -- Tipos corretos?
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name = 'dados_ibge'
    AND column_name IN ('codigo_ibge', 'ano');

  -- PK correta?
  SELECT tc.constraint_name
  FROM information_schema.table_constraints tc
  WHERE tc.table_schema = 'clean'
    AND tc.table_name = 'dados_ibge'
    AND tc.constraint_type = 'PRIMARY KEY';

ROLLBACK;
