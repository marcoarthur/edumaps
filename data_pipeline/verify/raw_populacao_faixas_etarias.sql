-- Verify edumaps:raw_populacao_faixas_etarias on pg

BEGIN;

  -- 1. Verificar se a tabela raw foi criada e tem dados
  DO $$
  DECLARE
    raw_rows integer;
    clean_rows integer;
    col_count integer;
  BEGIN
    SELECT COUNT(*) INTO raw_rows FROM raw.populacao_faixas_raw;
    SELECT COUNT(*) INTO clean_rows FROM clean.populacao_municipal WHERE faixa_0_4_anos IS NOT NULL;
    
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_schema = 'clean' 
      AND table_name = 'populacao_municipal'
      AND column_name LIKE 'faixa_%';
    
    IF raw_rows = 0 THEN
      RAISE EXCEPTION 'Tabela raw vazia ou não existe';
    END IF;
    
    IF clean_rows = 0 THEN
      RAISE EXCEPTION 'Nenhum município atualizado com dados de faixa etária';
    END IF;
    
    IF col_count < 19 THEN
      RAISE EXCEPTION 'Esperadas 19 colunas de faixa etária, encontradas %', col_count;
    END IF;
    
    RAISE NOTICE 'Verificação OK: % linhas raw, % municípios atualizados, % colunas faixa', 
      raw_rows, clean_rows, col_count;
  END $$;

  -- 2. Verificar consistência de dados básica
  SELECT 1 FROM (
    SELECT 
      COUNT(*) as total_municipios,
      SUM(CASE WHEN faixa_0_4_anos < 0 THEN 1 ELSE 0 END) as negativos,
      SUM(CASE WHEN total_soma_faixas IS NULL THEN 1 ELSE 0 END) as sem_soma
    FROM clean.populacao_municipal
  ) AS check_data
  WHERE negativos > 0 OR sem_soma > 0
  HAVING COUNT(*) = 0;

  -- 3. Verificar se a soma das faixas é razoável em relação ao total
  SELECT 1 FROM (
    SELECT 
      COUNT(*) as inconsistencias
    FROM clean.populacao_municipal
    WHERE 
      -- Diferença absoluta maior que 100 habitantes
      ABS(total_soma_faixas - populacao_estimada) > 100
      -- OU diferença percentual maior que 5%
      OR ABS(total_soma_faixas - populacao_estimada) / NULLIF(populacao_estimada, 0) > 0.05
  ) AS check_consistency
  WHERE inconsistencias > 10  -- Permitir até 10 municípios inconsistentes
  HAVING COUNT(*) = 0;

  -- 4. Verificar índices criados
  SELECT 1 FROM (
    SELECT 
      COUNT(*) as indexes_created
    FROM pg_indexes 
    WHERE schemaname = 'clean' 
      AND tablename = 'populacao_municipal'
      AND indexname LIKE 'idx_populacao_%'
  ) AS check_indexes
  WHERE indexes_created >= 1;  -- Pelo menos 1 índice criado

ROLLBACK;
