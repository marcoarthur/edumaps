-- Verify edumaps:raw_inep on pg

BEGIN;

  DO $$
    DECLARE
    raw_count integer;
    clean_count integer;
    raw_columns_count integer;
    clean_columns_count integer;

    BEGIN
      -- Verificar se as funções helper foram criadas
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'clean' AND routine_name = 'to_numeric_safe'
        ) THEN
        RAISE EXCEPTION 'Helper function clean.to_numeric_safe does not exist';
      END IF;

      IF NOT EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_schema = 'clean' AND routine_name = 'null_if_invalid'
        ) THEN
        RAISE EXCEPTION 'Helper function clean.null_if_invalid does not exist';
      END IF;
      -- Verificar tabela raw
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'raw' AND table_name = 'inep_raw'
        ) THEN
        RAISE EXCEPTION 'Table raw.inep_raw does not exist';
    END IF;

    -- Verificar tabela clean
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'clean' AND table_name = 'inep'
      ) THEN
      RAISE EXCEPTION 'Table clean.inep does not exist';
    END IF;

    -- Verificar dados na tabela raw
    SELECT COUNT(*) INTO raw_count FROM raw.inep_raw;
    IF raw_count = 0 THEN
      RAISE EXCEPTION 'Table raw.inep_raw is empty';
    END IF;

    -- Verificar dados na tabela clean
    SELECT COUNT(*) INTO clean_count FROM clean.inep;
    IF clean_count = 0 THEN
      RAISE EXCEPTION 'Table clean.inep is empty';
    END IF;

    -- Verificar colunas essenciais na tabela raw
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'raw' AND table_name = 'inep_raw' 
      AND column_name = 'co_municipio'
      ) THEN
      RAISE EXCEPTION 'Required column co_municipio is missing from raw.inep_raw';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'raw' AND table_name = 'inep_raw' 
      AND column_name = 'id_escola'
      ) THEN
      RAISE EXCEPTION 'Required column id_escola is missing from raw.inep_raw';
    END IF;

    -- Verificar colunas essenciais na tabela clean
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'clean' AND table_name = 'inep' 
      AND column_name = 'codigo_ibge'
      ) THEN
      RAISE EXCEPTION 'Required column codigo_ibge is missing from clean.inep';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'clean' AND table_name = 'inep' 
      AND column_name = 'linha_original'
      ) THEN
      RAISE EXCEPTION 'Required column linha_original is missing from clean.inep';
    END IF;

    -- Verificar conversão de tipos na tabela clean
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'clean' AND table_name = 'inep' 
      AND column_name = 'vl_nota_media_2023'
      AND data_type NOT IN ('numeric', 'real', 'double precision')
      ) THEN
      RAISE EXCEPTION 'Column vl_nota_media_2023 in clean.inep was not converted to numeric type';
    END IF;

    -- Contar colunas para verificar estrutura completa
    SELECT COUNT(*) INTO raw_columns_count 
    FROM information_schema.columns 
    WHERE table_schema = 'raw' AND table_name = 'inep_raw';

    SELECT COUNT(*) INTO clean_columns_count 
    FROM information_schema.columns 
    WHERE table_schema = 'clean' AND table_name = 'inep';

    -- Log de sucesso com estatísticas
    RAISE NOTICE 'VERIFICATION SUCCESSFUL:';
    RAISE NOTICE '- Raw table: % rows, % columns', raw_count, raw_columns_count;
    RAISE NOTICE '- Clean table: % rows, % columns', clean_count, clean_columns_count;
    RAISE NOTICE '- Data types converted correctly in clean schema';
    RAISE NOTICE '- All essential columns present';

  END 
$$;

ROLLBACK;
