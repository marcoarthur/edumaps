-- Verify edumaps:analytics_acessibility_views on pg

BEGIN;

  -- Verificar se a view materializada foi criada
  SELECT 
      COUNT(*) = 1 as view_materializada_criada
  FROM pg_matviews 
  WHERE schemaname = 'analytics' 
  AND matviewname = 'metricas_acessibilidade_municipios';

  -- Verificar estrutura da view
  SELECT 
      COUNT(*) = 11 as colunas_corretas,
      COUNT(*) FILTER (WHERE column_name = 'codigo_ibge') = 1 as tem_codigo_ibge,
      COUNT(*) FILTER (WHERE column_name = 'percentual_cobertura') = 1 as tem_cobertura,
      COUNT(*) FILTER (WHERE column_name = 'categoria_cobertura') = 1 as tem_categoria
  FROM information_schema.columns 
  WHERE table_schema = 'analytics' 
  AND table_name = 'metricas_acessibilidade_municipios';

  -- Verificar índices
  SELECT 
      COUNT(*) >= 4 as indices_criados,
      COUNT(*) FILTER (WHERE indexname = 'idx_metricas_acessibilidade_codigo') = 1 as indice_codigo
  FROM pg_indexes 
  WHERE schemaname = 'analytics' 
  AND tablename = 'metricas_acessibilidade_municipios';

  -- Verificar função de refresh
  SELECT 
      COUNT(*) = 1 as funcao_refresh_criada
  FROM information_schema.routines 
  WHERE routine_schema = 'analytics' 
  AND routine_name = 'refresh_metricas_acessibilidade';

  -- Verificar dados (pelo menos alguns municípios)
  SELECT 
      COUNT(*) > 0 as dados_populados,
      BOOL_AND(percentual_cobertura BETWEEN 0 AND 100) as cobertura_valida,
      BOOL_AND(densidade_escolas_km2 >= 0) as densidade_valida
  FROM analytics.metricas_acessibilidade_municipios
  LIMIT 100;

  -- Verificar view de estatísticas
  SELECT 
      COUNT(*) = 1 as view_estatisticas_criada,
      (SELECT total_municipios > 0 FROM analytics.estatisticas_acessibilidade) as tem_dados_estatisticas
  FROM analytics.estatisticas_acessibilidade;

ROLLBACK;
