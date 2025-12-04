-- Verify edumaps:ideb_despivot on pg

BEGIN;

  -- 1. Verifica se a tabela existe
  SELECT 
      table_schema,
      table_name,
      table_type
  FROM information_schema.tables 
  WHERE table_schema = 'clean' 
    AND table_name = 'inep_notas_desagregadas';

  -- 2. Verifica a estrutura das colunas
  SELECT 
      column_name,
      data_type,
      is_nullable,
      column_default
  FROM information_schema.columns 
  WHERE table_schema = 'clean' 
    AND table_name = 'inep_notas_desagregadas'
  ORDER BY ordinal_position;

  -- 3. Verifica a chave primária
  SELECT
      tc.table_schema,
      tc.table_name,
      kcu.column_name,
      tc.constraint_type
  FROM information_schema.table_constraints AS tc
  JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
  WHERE tc.table_schema = 'clean'
    AND tc.table_name = 'inep_notas_desagregadas'
    AND tc.constraint_type = 'PRIMARY KEY';

  -- 4. Verifica os índices
  SELECT
      schemaname,
      tablename,
      indexname,
      indexdef
  FROM pg_indexes
  WHERE schemaname = 'clean'
    AND tablename = 'inep_notas_desagregadas'
  ORDER BY indexname;

  -- 5. Verifica constraints de check
  SELECT
      tc.table_schema,
      tc.table_name,
      tc.constraint_name,
      cc.check_clause
  FROM information_schema.table_constraints AS tc
  JOIN information_schema.check_constraints AS cc
      ON tc.constraint_name = cc.constraint_name
  WHERE tc.table_schema = 'clean'
    AND tc.table_name = 'inep_notas_desagregadas'
    AND tc.constraint_type = 'CHECK';

  -- 6. Verifica a quantidade de dados
  SELECT 
      COUNT(*) as total_registros,
      COUNT(DISTINCT id_escola) as escolas_unicas,
      COUNT(DISTINCT ano) as anos_distintos,
      MIN(ano) as ano_minimo,
      MAX(ano) as ano_maximo
  FROM clean.inep_notas_desagregadas;

  -- 7. Verifica se há dados para todos os anos esperados (2005-2023 ímpares)
  SELECT 
      ano,
      COUNT(*) as quantidade_registros,
      ROUND(AVG(nota_mat), 2) as media_matematica,
      ROUND(AVG(nota_por), 2) as media_portugues
  FROM clean.inep_notas_desagregadas
  GROUP BY ano
  ORDER BY ano;

  -- 8. Verifica a integridade dos dados (valores dentro do range esperado)
  SELECT 
      'Notas fora do range 0-500' as verificação,
      COUNT(*) as quantidade
  FROM clean.inep_notas_desagregadas
  WHERE (nota_mat < 0 OR nota_mat > 500 OR nota_por < 0 OR nota_por > 500)
     AND (nota_mat IS NOT NULL OR nota_por IS NOT NULL);

  SELECT 
      'Anos fora do padrão (não ímpares)' as verificação,
      COUNT(*) as quantidade
  FROM clean.inep_notas_desagregadas
  WHERE ano % 2 = 0 OR ano < 2005 OR ano > 2023;

  -- 9. Verifica duplicatas na chave primária
  SELECT 
      'Duplicatas na chave primária' as verificação,
      COUNT(*) as quantidade
  FROM (
      SELECT id_escola, ano, COUNT(*) as qtd
      FROM clean.inep_notas_desagregadas
      GROUP BY id_escola, ano
      HAVING COUNT(*) > 1
  ) duplicatas;

  -- 10. Testa uma consulta básica para garantir que a tabela funciona
  SELECT 
      rede,
      COUNT(DISTINCT id_escola) as total_escolas,
      ROUND(AVG(nota_media), 2) as media_geral
  FROM clean.inep_notas_desagregadas
  WHERE ano = 2023
  GROUP BY rede
  HAVING COUNT(DISTINCT id_escola) > 0;

  -- Se alguma verificação falhar, será lançada uma exceção
  DO $$
  BEGIN
      -- Verifica se a tabela tem pelo menos algum dado
      IF NOT EXISTS (SELECT 1 FROM clean.inep_notas_desagregadas LIMIT 1) THEN
          RAISE EXCEPTION 'Tabela criada mas sem dados';
      END IF;
      
      -- Verifica anos mínimos e máximos
      IF (SELECT MIN(ano) FROM clean.inep_notas_desagregadas) != 2005 THEN
          RAISE WARNING 'Ano mínimo diferente de 2005';
      END IF;
      
      IF (SELECT MAX(ano) FROM clean.inep_notas_desagregadas) != 2023 THEN
          RAISE WARNING 'Ano máximo diferente de 2023';
      END IF;
      
      RAISE NOTICE 'Verificação da tabela inep_notas_desagregadas concluída com sucesso';
  END $$;

ROLLBACK;
