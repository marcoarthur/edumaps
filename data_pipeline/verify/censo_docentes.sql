-- Verify edumaps:censo_docentes on pg

BEGIN;

  -- Verifica existência da tabela
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name = 'censo_docentes';

  -- Verifica uma coluna chave
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name = 'censo_docentes'
    AND column_name = 'nu_ano_censo';

  -- Verifica se há pelo menos um registro (garantia do COPY)
  DO $$
  DECLARE
      row_count integer;
  BEGIN
      SELECT COUNT(*) INTO row_count FROM clean.censo_docentes;
      IF row_count = 0 THEN
          RAISE EXCEPTION 'Tabela clean.censo_docentes está vazia (COPY pode ter falhado)';
      END IF;
  END $$;

ROLLBACK;
