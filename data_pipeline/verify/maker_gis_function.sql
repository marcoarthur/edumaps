-- Verify edumaps:maker_gis_function on pg

BEGIN;

  -- Verifica se a função existe
  SELECT 1 FROM pg_proc 
  WHERE proname = 'get_cities_markers' 
    AND pronamespace = 'clean'::regnamespace;

  -- Verifica se a função retorna JSON (como esperado)
  DO $$
  DECLARE
      func_oid oid;
      result_type text;
  BEGIN
      SELECT oid INTO func_oid 
      FROM pg_proc 
      WHERE proname = 'get_cities_markers' 
        AND pronamespace = 'clean'::regnamespace;
      
      IF NOT FOUND THEN
          RAISE EXCEPTION 'Função clean.get_cities_markers não encontrada';
      END IF;
      
      result_type := pg_get_function_result(func_oid)::text;
      IF result_type NOT LIKE '%json%' THEN
          RAISE EXCEPTION 'Função clean.get_cities_markers não retorna JSON (retorna %)', result_type;
      END IF;
  END $$;

  -- Teste básico da função (com bounding box pequena)
  DO $$
  DECLARE
      test_result JSON;
  BEGIN
      -- Teste com uma bounding box aproximada de São Paulo
      -- Formato: min_lng, min_lat, max_lng, max_lat
      test_result := clean.get_cities_markers('-47.0,-24.0,-46.0,-23.0', 10, 5);
      
      -- Se a função retornar null ou vazia, não é necessariamente um erro
      -- (pode ser que não haja municípios naquela área ou tabela vazia)
      RAISE NOTICE 'Teste da função retornou % registros', 
                   COALESCE(json_array_length(test_result), 0);
      
      -- Não falha o teste se retornar vazio, apenas avisa
      IF test_result IS NULL OR json_array_length(test_result) = 0 THEN
          RAISE NOTICE 'Função retornou vazio (pode ser normal se não há dados)';
      END IF;
  END $$;

ROLLBACK;
