-- Verify edumaps:schemas on pg

BEGIN;
  -- Verificar se schemas foram criados
  SELECT 
      COUNT(*) = 5 as schemas_criados,
      COUNT(*) FILTER (WHERE schema_name = 'raw') = 1 as tem_raw,
      COUNT(*) FILTER (WHERE schema_name = 'clean') = 1 as tem_clean,
      COUNT(*) FILTER (WHERE schema_name = 'analytics') = 1 as tem_analytics,
      COUNT(*) FILTER (WHERE schema_name = 'postgis') = 1 as tem_postgis,
      COUNT(*) FILTER (WHERE schema_name = 'contrib') = 1 as tem_contrib
  FROM information_schema.schemata 
  WHERE schema_name IN ('raw', 'clean', 'analytics', 'postgis', 'contrib');

  -- Verificar search_path do banco (correção da conversão de array)
  SELECT 
      CASE 
          WHEN setting::text LIKE '%clean%' 
               AND setting::text LIKE '%analytics%'
               AND setting::text LIKE '%raw%'
          THEN true 
          ELSE false 
      END as search_path_semantico
  FROM pg_catalog.pg_settings 
  WHERE name = 'search_path' AND context = 'user';
ROLLBACK;
