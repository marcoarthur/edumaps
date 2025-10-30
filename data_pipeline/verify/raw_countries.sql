-- Verify edumaps:raw_countries on pg

BEGIN;

  -- Verificar se o servidor FDW foi criado
  SELECT 
      COUNT(*) = 1 as servidor_fdw_criado
  FROM pg_foreign_server 
  WHERE srvname = 'fds_geojson';

  -- Verificar se a tabela foreign foi importada
  SELECT 
      COUNT(*) = 1 as tabela_foreign_importada
  FROM information_schema.tables 
  WHERE table_schema = 'raw' AND table_name = 'countries_geo';

  -- Verificar se a tabela limpa foi criada
  SELECT 
      COUNT(*) = 1 as tabela_limpa_criada,
      COUNT(*) FILTER (WHERE column_name = 'geometry' AND data_type LIKE 'geography%') = 1 as tem_geografia
  FROM information_schema.columns 
  WHERE table_schema = 'clean' AND table_name = 'countries';

  -- Verificar se há dados nas tabelas
  SELECT 
      (SELECT COUNT(*) FROM raw.countries_geo) > 0 as dados_brutos_presentes,
      (SELECT COUNT(*) FROM clean.countries) > 0 as dados_limpos_presentes;

  -- Verificar índices
  SELECT 
      COUNT(*) >= 2 as indices_criados,
      COUNT(*) FILTER (WHERE indexname = 'ix_countries_geometry') = 1 as indice_geometria,
      COUNT(*) FILTER (WHERE indexname = 'ix_countries_name') = 1 as indice_nome
  FROM pg_indexes 
  WHERE schemaname = 'clean' AND tablename = 'countries';

ROLLBACK;
