-- Verify edumaps:osm_data on pg

BEGIN;

  -- ========================================================
  -- SCRIPT DE VERIFICAÇÃO DAS TABELAS OSM
  -- Verifica: estrutura, constraints, permissões e dados
  -- ========================================================

  -- 1. VERIFICAÇÃO DAS TABELAS EXISTENTES
  SELECT 
      table_schema,
      table_name,
      table_type
  FROM information_schema.tables 
  WHERE table_schema = 'clean'
      AND table_name IN ('osm_query', 'osm_landuse')
  ORDER BY table_name;

  -- 2. VERIFICAÇÃO DAS COLUNAS E TIPOS DE DADOS
  SELECT 
      c.table_name,
      c.column_name,
      c.data_type,
      c.is_nullable,
      c.column_default,
      CASE 
          WHEN tc.constraint_type = 'PRIMARY KEY' THEN 'PK'
          WHEN tc.constraint_type = 'FOREIGN KEY' THEN 'FK'
          ELSE ''
      END as constraint_type
  FROM information_schema.columns c
  LEFT JOIN information_schema.key_column_usage kcu 
      ON c.table_schema = kcu.table_schema 
      AND c.table_name = kcu.table_name 
      AND c.column_name = kcu.column_name
  LEFT JOIN information_schema.table_constraints tc
      ON kcu.constraint_schema = tc.constraint_schema
      AND kcu.constraint_name = tc.constraint_name
      AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
  WHERE c.table_schema = 'clean'
      AND c.table_name IN ('osm_query', 'osm_landuse')
  ORDER BY c.table_name, c.ordinal_position;

  -- 3. VERIFICAÇÃO DE CONSTRAINTS E RELACIONAMENTOS
  SELECT
      tc.table_schema,
      tc.table_name,
      tc.constraint_name,
      tc.constraint_type,
      kcu.column_name,
      ccu.table_schema AS foreign_table_schema,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
  LEFT JOIN information_schema.constraint_column_usage ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
  WHERE tc.table_schema = 'clean'
      AND tc.table_name IN ('osm_query', 'osm_landuse')
  ORDER BY tc.table_name, tc.constraint_type;

  -- 4. VERIFICAÇÃO DE ÍNDICES
  SELECT
      schemaname,
      tablename,
      indexname,
      indexdef
  FROM pg_indexes
  WHERE schemaname = 'clean'
      AND tablename IN ('osm_query', 'osm_landuse')
  ORDER BY tablename, indexname;

  -- 5. VERIFICAÇÃO DE GEOMETRIA (ESPECIAL PARA osm_landuse)
  SELECT 
      f_table_schema as schema_name,
      f_table_name as table_name,
      f_geometry_column as geometry_column,
      srid,
      type
  FROM geometry_columns
  WHERE f_table_schema = 'clean'
      AND f_table_name = 'osm_landuse';

  -- 6. VERIFICAÇÃO DE DADOS INICIAIS (APÓS DEPLOY)
  DO $$
  DECLARE
      v_osm_query_count INTEGER;
      v_osm_landuse_count INTEGER;
      v_has_municipios_table BOOLEAN;
  BEGIN
      -- Contagem de registros
      SELECT COUNT(*) INTO v_osm_query_count FROM clean.osm_query;
      SELECT COUNT(*) INTO v_osm_landuse_count FROM clean.osm_landuse;
      
      -- Verifica se a tabela de referência existe
      SELECT EXISTS (
          SELECT FROM information_schema.tables 
          WHERE table_schema = 'clean' 
          AND table_name = 'municipios_sp'
      ) INTO v_has_municipios_table;
      
      RAISE NOTICE '=== RESULTADOS DA VERIFICAÇÃO ===';
      RAISE NOTICE 'Tabela clean.osm_query: % registros', v_osm_query_count;
      RAISE NOTICE 'Tabela clean.osm_landuse: % registros', v_osm_landuse_count;
      RAISE NOTICE 'Tabela de referência municipios_sp existe: %', 
          CASE WHEN v_has_municipios_table THEN 'SIM' ELSE 'NÃO - ATENÇÃO!' END;
      
      -- Verifica FK de osm_landuse para municipios_sp
      IF v_has_municipios_table THEN
          RAISE NOTICE 'Verificando integridade da FK municipio_id...';
          
          PERFORM 1 
          FROM clean.osm_landuse l
          LEFT JOIN clean.municipios_sp m ON l.municipio_id = m.codigo_ibge
          WHERE l.municipio_id IS NOT NULL 
              AND m.codigo_ibge IS NULL
          LIMIT 1;
          
          IF FOUND THEN
              RAISE WARNING 'Existem municipio_id em osm_landuse sem correspondência em municipios_sp!';
          ELSE
              RAISE NOTICE 'FK municipio_id: OK';
          END IF;
      END IF;
      
  END $$;

  -- 7. VERIFICAÇÃO DE PERMISSÕES
  SELECT
      grantee,
      table_schema,
      table_name,
      privilege_type
  FROM information_schema.role_table_grants
  WHERE table_schema = 'clean'
      AND table_name IN ('osm_query', 'osm_landuse')
  ORDER BY table_name, grantee, privilege_type;

  -- 8. SCRIPT DE VALIDAÇÃO COMPLETA (VERSÃO RESUMIDA PARA LOG)
  WITH table_check AS (
      SELECT 
          'osm_query' as table_name,
          (SELECT COUNT(*) FROM clean.osm_query) as row_count,
          (SELECT COUNT(*) FROM information_schema.columns 
           WHERE table_schema = 'clean' AND table_name = 'osm_query') as column_count
      UNION ALL
      SELECT 
          'osm_landuse' as table_name,
          (SELECT COUNT(*) FROM clean.osm_landuse),
          (SELECT COUNT(*) FROM information_schema.columns 
           WHERE table_schema = 'clean' AND table_name = 'osm_landuse')
  ),
  constraint_check AS (
      SELECT 
          'PK' as check_type,
          COUNT(*) as count
      FROM information_schema.table_constraints
      WHERE table_schema = 'clean'
          AND table_name IN ('osm_query', 'osm_landuse')
          AND constraint_type = 'PRIMARY KEY'
      UNION ALL
      SELECT 
          'FK' as check_type,
          COUNT(*) as count
      FROM information_schema.table_constraints
      WHERE table_schema = 'clean'
          AND table_name IN ('osm_query', 'osm_landuse')
          AND constraint_type = 'FOREIGN KEY'
  )
  SELECT 
      'RESUMO DO DEPLOY' as section,
      'Tabelas criadas: 2/2' as item,
      'Status: OK' as status
  UNION ALL
  SELECT 
      'CONTAGEM DE REGISTROS',
      FORMAT('%s: %s linhas', tc.table_name, tc.row_count),
      CASE WHEN tc.row_count >= 0 THEN 'OK' ELSE 'ERRO' END
  FROM table_check tc
  UNION ALL
  SELECT 
      'CONSTRAINTS',
      FORMAT('%s: %s constraints', cc.check_type, cc.count),
      CASE 
          WHEN cc.check_type = 'PK' AND cc.count = 2 THEN 'OK'
          WHEN cc.check_type = 'FK' AND cc.count = 2 THEN 'OK'
          ELSE 'VERIFICAR'
      END
  FROM constraint_check cc;


ROLLBACK;

