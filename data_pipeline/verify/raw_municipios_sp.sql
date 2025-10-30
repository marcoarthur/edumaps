-- Verify edumaps:raw_municipios_sp on pg

BEGIN;

  -- Verificar se o servidor FDW foi criado
  SELECT 
      COUNT(*) = 1 as servidor_fdw_criado
  FROM pg_foreign_server 
  WHERE srvname = 'fdw_municipios_sp';

  -- Verificar se a tabela foreign foi importada
  SELECT 
      COUNT(*) = 1 as tabela_foreign_importada
  FROM information_schema.tables 
  WHERE table_schema = 'raw' AND table_name = 'sp_municipios_2024';

  -- Verificar se a tabela limpa foi criada com todas as colunas semânticas
  SELECT 
      COUNT(*) = 18 as colunas_semanticas_criadas,
      COUNT(*) FILTER (WHERE column_name = 'codigo_ibge') = 1 as tem_codigo_ibge,
      COUNT(*) FILTER (WHERE column_name = 'nome') = 1 as tem_nome,
      COUNT(*) FILTER (WHERE column_name = 'geometry' AND data_type LIKE 'geometry%') = 1 as tem_geometry,
      COUNT(*) FILTER (WHERE column_name = 'geometria_corrigida') = 1 as tem_flag_correcao
  FROM information_schema.columns 
  WHERE table_schema = 'clean' AND table_name = 'municipios_sp';

  -- Verificar integridade dos dados
  SELECT 
      COUNT(*) > 0 as dados_presentes,
      COUNT(DISTINCT codigo_ibge) = COUNT(*) as codigos_ibge_unicos,
      COUNT(*) FILTER (WHERE sigla_estado = 'SP') = COUNT(*) as todos_sao_sp,
      COUNT(*) FILTER (WHERE NOT ST_IsValid(geometry)) = 0 as todas_geometrias_validas,
      COUNT(*) FILTER (WHERE geometria_corrigida = true) as geometrias_corrigidas
  FROM clean.municipios_sp;

  -- Verificar índices
  SELECT 
      COUNT(*) >= 6 as indices_criados,
      COUNT(*) FILTER (WHERE indexname = 'ix_municipios_sp_geometry') = 1 as indice_geometria,
      COUNT(*) FILTER (WHERE indexname = 'ix_municipios_sp_codigo_ibge') = 1 as indice_codigo_ibge,
      COUNT(*) FILTER (WHERE indexname = 'pk_municipios_sp') = 1 as primary_key
  FROM pg_indexes 
  WHERE schemaname = 'clean' AND tablename = 'municipios_sp';

ROLLBACK;
