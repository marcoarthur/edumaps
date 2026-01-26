-- Deploy edumaps:raw_populacao_faixas_etarias to pg
-- requires: raw_populacao

BEGIN;

  -- Criar tabela raw para importação do CSV de faixas etárias
  DROP TABLE IF EXISTS raw.populacao_faixas_raw;
  CREATE TABLE raw.populacao_faixas_raw (
      codigo_ibge CHAR(7),
      municipio VARCHAR(100),
      populacao_total INTEGER,
      faixa_0_4_anos VARCHAR(20),
      faixa_5_9_anos VARCHAR(20),
      faixa_10_14_anos VARCHAR(20),
      faixa_15_19_anos VARCHAR(20),
      faixa_20_24_anos VARCHAR(20),
      faixa_30_34_anos VARCHAR(20),
      faixa_35_39_anos VARCHAR(20),
      faixa_40_44_anos VARCHAR(20),
      faixa_45_49_anos VARCHAR(20),
      faixa_50_54_anos VARCHAR(20),
      faixa_55_59_anos VARCHAR(20),
      faixa_60_64_anos VARCHAR(20),
      faixa_65_69_anos VARCHAR(20),
      faixa_70_74_anos VARCHAR(20),
      faixa_75_79_anos VARCHAR(20),
      faixa_80_84_anos VARCHAR(20),
      faixa_85_89_anos VARCHAR(20),
      faixa_95_99_anos VARCHAR(20),
      faixa_100_mais VARCHAR(20)
  );

  -- Importar dados do CSV (ajustar caminho para seu ambiente)
  COPY raw.populacao_faixas_raw
  FROM '/data/populacao_faixas_etarias.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ',');

  -- Log: estatísticas da importação
  DO $$
  DECLARE
    row_count integer;
    null_0_4 integer;
    null_100_mais integer;
  BEGIN
    SELECT COUNT(*) INTO row_count FROM raw.populacao_faixas_raw;
    SELECT COUNT(*) INTO null_0_4 FROM raw.populacao_faixas_raw WHERE faixa_0_4_anos = '-' OR faixa_0_4_anos IS NULL;
    SELECT COUNT(*) INTO null_100_mais FROM raw.populacao_faixas_raw WHERE faixa_100_mais = '-' OR faixa_100_mais IS NULL;
    
    RAISE NOTICE 'Importadas % linhas do CSV de faixas etárias', row_count;
    RAISE NOTICE 'Valores ausentes na faixa 0-4: %', null_0_4;
    RAISE NOTICE 'Valores ausentes na faixa 100+: %', null_100_mais;
  END $$;

  -- 1. PRIMEIRO: Adicionar todas as colunas de faixas etárias à tabela existente
  DO $$
  BEGIN
    -- Faixas etárias principais (0 a 14 anos)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_0_4_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_0_4_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_5_9_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_5_9_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_10_14_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_10_14_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_15_19_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_15_19_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_20_24_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_20_24_anos INTEGER;
    END IF;
    
    -- Adultos jovens (30 a 59 anos)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_30_34_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_30_34_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_35_39_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_35_39_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_40_44_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_40_44_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_45_49_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_45_49_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_50_54_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_50_54_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_55_59_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_55_59_anos INTEGER;
    END IF;
    
    -- Idosos (60 anos ou mais)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_60_64_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_60_64_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_65_69_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_65_69_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_70_74_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_70_74_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_75_79_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_75_79_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_80_84_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_80_84_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_85_89_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_85_89_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_95_99_anos') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_95_99_anos INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_schema = 'clean' 
                  AND table_name = 'populacao_municipal' 
                  AND column_name = 'faixa_100_mais') THEN
      ALTER TABLE clean.populacao_municipal 
        ADD COLUMN faixa_100_mais INTEGER;
    END IF;
    
  END $$;

  -- 2. SEGUNDO: Atualizar os dados na tabela existente
  UPDATE clean.populacao_municipal pm
  SET 
    faixa_0_4_anos = CASE 
      WHEN r.faixa_0_4_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_0_4_anos, '.', '')::INTEGER
    END,
    faixa_5_9_anos = CASE 
      WHEN r.faixa_5_9_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_5_9_anos, '.', '')::INTEGER
    END,
    faixa_10_14_anos = CASE 
      WHEN r.faixa_10_14_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_10_14_anos, '.', '')::INTEGER
    END,
    faixa_15_19_anos = CASE 
      WHEN r.faixa_15_19_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_15_19_anos, '.', '')::INTEGER
    END,
    faixa_20_24_anos = CASE 
      WHEN r.faixa_20_24_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_20_24_anos, '.', '')::INTEGER
    END,
    faixa_30_34_anos = CASE 
      WHEN r.faixa_30_34_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_30_34_anos, '.', '')::INTEGER
    END,
    faixa_35_39_anos = CASE 
      WHEN r.faixa_35_39_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_35_39_anos, '.', '')::INTEGER
    END,
    faixa_40_44_anos = CASE 
      WHEN r.faixa_40_44_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_40_44_anos, '.', '')::INTEGER
    END,
    faixa_45_49_anos = CASE 
      WHEN r.faixa_45_49_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_45_49_anos, '.', '')::INTEGER
    END,
    faixa_50_54_anos = CASE 
      WHEN r.faixa_50_54_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_50_54_anos, '.', '')::INTEGER
    END,
    faixa_55_59_anos = CASE 
      WHEN r.faixa_55_59_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_55_59_anos, '.', '')::INTEGER
    END,
    faixa_60_64_anos = CASE 
      WHEN r.faixa_60_64_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_60_64_anos, '.', '')::INTEGER
    END,
    faixa_65_69_anos = CASE 
      WHEN r.faixa_65_69_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_65_69_anos, '.', '')::INTEGER
    END,
    faixa_70_74_anos = CASE 
      WHEN r.faixa_70_74_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_70_74_anos, '.', '')::INTEGER
    END,
    faixa_75_79_anos = CASE 
      WHEN r.faixa_75_79_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_75_79_anos, '.', '')::INTEGER
    END,
    faixa_80_84_anos = CASE 
      WHEN r.faixa_80_84_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_80_84_anos, '.', '')::INTEGER
    END,
    faixa_85_89_anos = CASE 
      WHEN r.faixa_85_89_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_85_89_anos, '.', '')::INTEGER
    END,
    faixa_95_99_anos = CASE 
      WHEN r.faixa_95_99_anos = '-' THEN NULL
      ELSE REPLACE(r.faixa_95_99_anos, '.', '')::INTEGER
    END,
    faixa_100_mais = CASE 
      WHEN r.faixa_100_mais = '-' THEN NULL
      ELSE REPLACE(r.faixa_100_mais, '.', '')::INTEGER
    END
  FROM raw.populacao_faixas_raw r
  WHERE pm.codigo_ibge = r.codigo_ibge;

  -- 3. TERCEIRO: Log de atualização
  DO $$
  DECLARE
    updated_count integer;
    null_count integer;
  BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM clean.populacao_municipal
    WHERE faixa_0_4_anos IS NOT NULL;
    
    SELECT COUNT(*) INTO null_count
    FROM raw.populacao_faixas_raw r
    LEFT JOIN clean.populacao_municipal pm ON r.codigo_ibge = pm.codigo_ibge
    WHERE pm.codigo_ibge IS NULL;
    
    RAISE NOTICE 'Municípios atualizados com dados de faixa etária: %', updated_count;
    RAISE NOTICE 'Códigos IBGE no CSV sem correspondência na tabela: %', null_count;
  END $$;

  -- 4. QUARTO: Calcular colunas derivadas (somas de grupos etários)
  ALTER TABLE clean.populacao_municipal 
    ADD COLUMN IF NOT EXISTS pop_0_a_14 INTEGER,
    ADD COLUMN IF NOT EXISTS pop_15_a_24 INTEGER,
    ADD COLUMN IF NOT EXISTS pop_25_a_59 INTEGER,
    ADD COLUMN IF NOT EXISTS pop_60_mais INTEGER,
    ADD COLUMN IF NOT EXISTS total_soma_faixas INTEGER;

  UPDATE clean.populacao_municipal 
  SET 
    pop_0_a_14 = COALESCE(faixa_0_4_anos, 0) + 
                 COALESCE(faixa_5_9_anos, 0) + 
                 COALESCE(faixa_10_14_anos, 0),
    
    pop_15_a_24 = COALESCE(faixa_15_19_anos, 0) + 
                  COALESCE(faixa_20_24_anos, 0),
    
    pop_25_a_59 = COALESCE(faixa_30_34_anos, 0) + 
                  COALESCE(faixa_35_39_anos, 0) + 
                  COALESCE(faixa_40_44_anos, 0) + 
                  COALESCE(faixa_45_49_anos, 0) + 
                  COALESCE(faixa_50_54_anos, 0) + 
                  COALESCE(faixa_55_59_anos, 0),
    
    pop_60_mais = COALESCE(faixa_60_64_anos, 0) + 
                  COALESCE(faixa_65_69_anos, 0) + 
                  COALESCE(faixa_70_74_anos, 0) + 
                  COALESCE(faixa_75_79_anos, 0) + 
                  COALESCE(faixa_80_84_anos, 0) + 
                  COALESCE(faixa_85_89_anos, 0) + 
                  COALESCE(faixa_95_99_anos, 0) + 
                  COALESCE(faixa_100_mais, 0),
    
    total_soma_faixas = COALESCE(faixa_0_4_anos, 0) + COALESCE(faixa_5_9_anos, 0) + 
                       COALESCE(faixa_10_14_anos, 0) + COALESCE(faixa_15_19_anos, 0) +
                       COALESCE(faixa_20_24_anos, 0) + COALESCE(faixa_30_34_anos, 0) +
                       COALESCE(faixa_35_39_anos, 0) + COALESCE(faixa_40_44_anos, 0) +
                       COALESCE(faixa_45_49_anos, 0) + COALESCE(faixa_50_54_anos, 0) +
                       COALESCE(faixa_55_59_anos, 0) + COALESCE(faixa_60_64_anos, 0) +
                       COALESCE(faixa_65_69_anos, 0) + COALESCE(faixa_70_74_anos, 0) +
                       COALESCE(faixa_75_79_anos, 0) + COALESCE(faixa_80_84_anos, 0) +
                       COALESCE(faixa_85_89_anos, 0) + COALESCE(faixa_95_99_anos, 0) +
                       COALESCE(faixa_100_mais, 0);

  -- 5. QUINTO: Log de consistência dos dados
  DO $$
  DECLARE
    total_faixas bigint;
    diff_count integer;
    diff_percent numeric;
  BEGIN
    -- Calcular soma total das faixas
    SELECT SUM(total_soma_faixas) INTO total_faixas
    FROM clean.populacao_municipal;
    
    -- Contar diferenças significativas (>10 habitantes ou >1%)
    SELECT COUNT(*) INTO diff_count
    FROM clean.populacao_municipal
    WHERE ABS(total_soma_faixas - populacao_estimada) > 10
       OR ABS(total_soma_faixas - populacao_estimada) / NULLIF(populacao_estimada, 0) > 0.01;
    
    -- Calcular diferença percentual média
    SELECT AVG(
      ABS(total_soma_faixas - populacao_estimada) / NULLIF(populacao_estimada, 0) * 100
    ) INTO diff_percent
    FROM clean.populacao_municipal
    WHERE populacao_estimada > 0;
    
    RAISE NOTICE 'Soma total das faixas etárias: %', total_faixas;
    RAISE NOTICE 'Municípios com diferença >10 hab ou >1%%: %', diff_count;
    RAISE NOTICE 'Diferença percentual média: % %%', ROUND(COALESCE(diff_percent, 0), 2);
  END $$;

  -- 6. SEXTO: Adicionar comentários para documentação
  COMMENT ON COLUMN clean.populacao_municipal.faixa_0_4_anos IS 'População de 0 a 4 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_5_9_anos IS 'População de 5 a 9 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_10_14_anos IS 'População de 10 a 14 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_15_19_anos IS 'População de 15 a 19 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_20_24_anos IS 'População de 20 a 24 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_30_34_anos IS 'População de 30 a 34 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_35_39_anos IS 'População de 35 a 39 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_40_44_anos IS 'População de 40 a 44 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_45_49_anos IS 'População de 45 a 49 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_50_54_anos IS 'População de 50 a 54 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_55_59_anos IS 'População de 55 a 59 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_60_64_anos IS 'População de 60 a 64 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_65_69_anos IS 'População de 65 a 69 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_70_74_anos IS 'População de 70 a 74 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_75_79_anos IS 'População de 75 a 79 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_80_84_anos IS 'População de 80 a 84 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_85_89_anos IS 'População de 85 a 89 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_95_99_anos IS 'População de 95 a 99 anos - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.faixa_100_mais IS 'População de 100 anos ou mais - Fonte: IBGE';

  COMMENT ON COLUMN clean.populacao_municipal.pop_0_a_14 IS 'População consolidada de 0 a 14 anos (soma das faixas)';
  COMMENT ON COLUMN clean.populacao_municipal.pop_15_a_24 IS 'População consolidada de 15 a 24 anos (soma das faixas)';
  COMMENT ON COLUMN clean.populacao_municipal.pop_25_a_59 IS 'População consolidada de 25 a 59 anos (soma das faixas 30-59)';
  COMMENT ON COLUMN clean.populacao_municipal.pop_60_mais IS 'População consolidada de 60 anos ou mais (soma das faixas)';
  COMMENT ON COLUMN clean.populacao_municipal.total_soma_faixas IS 'Soma total de todas as faixas etárias (para validação)';

  -- 7. SÉTIMO: Criar índices para melhor performance
  CREATE INDEX IF NOT EXISTS idx_populacao_faixa_0_4 ON clean.populacao_municipal (faixa_0_4_anos);
  CREATE INDEX IF NOT EXISTS idx_populacao_faixa_15_19 ON clean.populacao_municipal (faixa_15_19_anos);
  CREATE INDEX IF NOT EXISTS idx_populacao_faixa_60_64 ON clean.populacao_municipal (faixa_60_64_anos);
  CREATE INDEX IF NOT EXISTS idx_populacao_grupos ON clean.populacao_municipal (pop_0_a_14, pop_15_a_24, pop_25_a_59, pop_60_mais);

COMMIT;
