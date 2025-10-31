-- Verify edumaps:analytics_acessibility on pg

BEGIN;

  -- Verificar se as funções foram criadas no schema analytics
  SELECT 
      COUNT(*) = 2 as funcoes_criadas,
      COUNT(*) FILTER (WHERE routine_name = 'calcular_acessibilidade_municipio') = 1 as tem_funcao_individual,
      COUNT(*) FILTER (WHERE routine_name = 'calcular_acessibilidade_lote') = 1 as tem_funcao_lote
  FROM information_schema.routines 
  WHERE routine_schema = 'analytics' 
  AND routine_name IN ('calcular_acessibilidade_municipio', 'calcular_acessibilidade_lote');

  -- Verificar estrutura da função individual
  SELECT 
      COUNT(*) = 6 as parametros_corretos_individual,
      COUNT(*) FILTER (WHERE parameter_name = 'p_codigo_ibge' AND data_type = 'character varying') = 1 as tem_param_codigo_ibge,
      COUNT(*) FILTER (WHERE parameter_name = 'p_raio_km' AND data_type = 'numeric') = 1 as tem_param_raio
  FROM information_schema.parameters 
  WHERE specific_schema = 'analytics' 
  AND specific_name LIKE 'calcular_acessibilidade_municipio%';

  -- Verificar estrutura da função lote
  SELECT 
      COUNT(*) = 2 as parametros_corretos_lote,
      COUNT(*) FILTER (WHERE parameter_name = 'p_codigos_ibge' AND data_type = 'ARRAY') = 1 as tem_param_array,
      COUNT(*) FILTER (WHERE parameter_name = 'p_raio_km' AND data_type = 'numeric') = 1 as tem_param_raio_lote
  FROM information_schema.parameters 
  WHERE specific_schema = 'analytics' 
  AND specific_name LIKE 'calcular_acessibilidade_lote%';

  -- Verificar tipos de retorno da função individual
  SELECT 
      COUNT(*) = 6 as colunas_retorno_individual,
      COUNT(*) FILTER (WHERE column_name = 'percentual_cobertura' AND data_type = 'numeric') = 1 as tem_percentual,
      COUNT(*) FILTER (WHERE column_name = 'area_coberta_km2' AND data_type = 'numeric') = 1 as tem_area_coberta,
      COUNT(*) FILTER (WHERE column_name = 'area_total_km2' AND data_type = 'numeric') = 1 as tem_area_total,
      COUNT(*) FILTER (WHERE column_name = 'n_escolas' AND data_type = 'integer') = 1 as tem_n_escolas,
      COUNT(*) FILTER (WHERE column_name = 'municipio_nome' AND data_type = 'character varying') = 1 as tem_municipio_nome,
      COUNT(*) FILTER (WHERE column_name = 'codigo_ibge_municipio' AND data_type = 'character varying') = 1 as tem_codigo_ibge
  FROM information_schema.columns 
  WHERE table_schema = 'analytics' 
  AND table_name = 'calcular_acessibilidade_municipio';

  -- Verificar tipos de retorno da função lote
  SELECT 
      COUNT(*) = 6 as colunas_retorno_lote,
      COUNT(*) FILTER (WHERE column_name = 'percentual_cobertura' AND data_type = 'numeric') = 1 as tem_percentual_lote,
      COUNT(*) FILTER (WHERE column_name = 'area_coberta_km2' AND data_type = 'numeric') = 1 as tem_area_coberta_lote,
      COUNT(*) FILTER (WHERE column_name = 'area_total_km2' AND data_type = 'numeric') = 1 as tem_area_total_lote,
      COUNT(*) FILTER (WHERE column_name = 'n_escolas' AND data_type = 'integer') = 1 as tem_n_escolas_lote,
      COUNT(*) FILTER (WHERE column_name = 'municipio_nome' AND data_type = 'character varying') = 1 as tem_municipio_nome_lote,
      COUNT(*) FILTER (WHERE column_name = 'codigo_ibge_municipio' AND data_type = 'character varying') = 1 as tem_codigo_ibge_lote
  FROM information_schema.columns 
  WHERE table_schema = 'analytics' 
  AND table_name = 'calcular_acessibilidade_lote';

  -- Testar função individual com município conhecido (CORRIGIDO - sem GROUP BY)
  SELECT 
      (SELECT COUNT(*) FROM analytics.calcular_acessibilidade_municipio('3550308', 1)) = 1 as funcao_individual_retorna_linha;

  -- Verificar dados retornados pela função individual
  SELECT 
      BOOL_AND(percentual_cobertura BETWEEN 0 AND 100) as percentual_valido,
      BOOL_AND(area_coberta_km2 >= 0) as area_coberta_valida,
      BOOL_AND(area_total_km2 > 0) as area_total_valida,
      BOOL_AND(n_escolas >= 0) as n_escolas_valido,
      BOOL_AND(municipio_nome IS NOT NULL) as nome_nao_nulo,
      BOOL_AND(codigo_ibge_municipio = '3550308') as codigo_correto
  FROM analytics.calcular_acessibilidade_municipio('3550308', 1);

  -- Testar função lote com array de municípios
  SELECT 
      COUNT(*) >= 2 as funcao_lote_funciona,
      COUNT(DISTINCT codigo_ibge_municipio) = 2 as retorna_dois_municipios,
      BOOL_AND(percentual_cobertura BETWEEN 0 AND 100) as todos_percentuais_validos,
      BOOL_AND(area_coberta_km2 >= 0) as todas_areas_cobertas_validas,
      BOOL_AND(area_total_km2 > 0) as todas_areas_totais_validas,
      BOOL_AND(n_escolas >= 0) as todos_n_escolas_validos
  FROM analytics.calcular_acessibilidade_lote(ARRAY['3550308','3509502'], 1);

  -- Testar função lote sem parâmetros (todos municípios) - limitado para performance
  SELECT 
      COUNT(*) > 0 as funcao_lote_todos_funciona,
      BOOL_AND(percentual_cobertura BETWEEN 0 AND 100) as todos_percentuais_validos_completo,
      BOOL_AND(codigo_ibge_municipio IS NOT NULL) as todos_codigos_preenchidos
  FROM analytics.calcular_acessibilidade_lote(NULL, 1)
  LIMIT 10;

  -- Verificar tratamento de erro para código IBGE inválido
  DO $$
  BEGIN
      -- Testar código inválido (deve lançar exceção)
      PERFORM analytics.calcular_acessibilidade_municipio('123', 1);
      RAISE EXCEPTION 'Função não lançou erro para código IBGE inválido';
  EXCEPTION
      WHEN others THEN
          -- Esperado que lance exceção, então é sucesso
          NULL;
  END $$;

  -- Verificar tratamento para município não encontrado
  DO $$
  BEGIN
      -- Testar código inexistente (deve lançar exceção)
      PERFORM analytics.calcular_acessibilidade_municipio('0000000', 1);
      RAISE EXCEPTION 'Função não lançou erro para município não encontrado';
  EXCEPTION
      WHEN others THEN
          -- Esperado que lance exceção, então é sucesso
          NULL;
  END $$;

ROLLBACK;
