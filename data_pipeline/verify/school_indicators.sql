-- Verify edumaps:school_indicators on pg

BEGIN;

  -- Verifica existência da tabela
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name = 'school_indicators';

  -- Verifica colunas-chave do censo e dos indicadores derivados
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = 'clean' AND table_name = 'school_indicators'
    AND column_name IN ('co_entidade', 'prop_licenciatura', 'nota_media', 'ano_ideb');

  -- Verifica PK
  SELECT 1 FROM pg_constraint
  WHERE conrelid = 'clean.school_indicators'::regclass
    AND contype = 'p';

ROLLBACK;