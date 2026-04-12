-- Verify edumaps:analytics_municipios_similaridade on pg


BEGIN;

  -- 1. Verificar se a materialized view existe
  SELECT 1 FROM pg_matviews 
  WHERE schemaname = 'analytics' AND matviewname = 'municipio_similaridade';

  -- 2. Verificar se os índices existem
  SELECT indexname FROM pg_indexes 
  WHERE schemaname = 'analytics' AND tablename = 'municipio_similaridade'
  ORDER BY indexname;

  -- 3. Verificar estrutura das colunas
  SELECT 
    column_name,
    data_type,
    is_nullable
  FROM information_schema.columns 
  WHERE table_schema = 'analytics' 
    AND table_name = 'municipio_similaridade'
  ORDER BY ordinal_position;

  -- 4. Contar registros
  SELECT COUNT(*) AS total_pares 
  FROM analytics.municipio_similaridade;

  -- 5. Mostrar amostra dos dados (top 10 mais similares)
  SELECT 
      municipio_1,
      municipio_2,
      ROUND(similaridade::numeric, 6) AS similaridade,
      ROUND(distancia_euclidiana::numeric, 2) AS distancia
  FROM analytics.municipio_similaridade
  ORDER BY similaridade DESC
  LIMIT 10;

  -- Se chegou até aqui, a migration está ok

COMMIT;
