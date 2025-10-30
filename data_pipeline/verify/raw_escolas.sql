-- Verify edumaps:raw_escolas on pg

BEGIN;

  -- Verificar se as tabelas foram criadas
  SELECT 
      COUNT(*) = 2 as tabelas_criadas,
      COUNT(*) FILTER (WHERE table_name = 'escolas_raw' AND table_schema = 'raw') = 1 as tem_raw,
      COUNT(*) FILTER (WHERE table_name = 'escolas' AND table_schema = 'clean') = 1 as tem_clean
  FROM information_schema.tables 
  WHERE (table_schema = 'raw' AND table_name = 'escolas_raw')
     OR (table_schema = 'clean' AND table_name = 'escolas');

  -- Verificar estrutura da tabela clean
  SELECT 
      COUNT(*) >= 20 as colunas_criadas,
      COUNT(*) FILTER (WHERE column_name = 'codigo_inep' AND data_type = 'bigint') = 1 as tem_codigo_inep,
      COUNT(*) FILTER (WHERE column_name = 'geometry' AND data_type LIKE 'geometry%') = 1 as tem_geometry,
      COUNT(*) FILTER (WHERE column_name = 'latitude' AND data_type = 'double precision') = 1 as tem_latitude
  FROM information_schema.columns 
  WHERE table_schema = 'clean' AND table_name = 'escolas';

  -- Verificar integridade dos dados
  SELECT 
      COUNT(*) > 0 as dados_presentes,
      COUNT(DISTINCT codigo_inep) = COUNT(*) as codigos_inep_unicos,
      COUNT(*) FILTER (WHERE geometry IS NULL) = 0 as todas_geometrias_preenchidas,
      COUNT(*) FILTER (WHERE NOT ST_IsValid(geometry)) = 0 as todas_geometrias_validas,
      COUNT(*) FILTER (WHERE uf = 'SP') as escolas_sp
  FROM clean.escolas;

  -- Verificar índices
  SELECT 
      COUNT(*) >= 4 as indices_criados,
      COUNT(*) FILTER (WHERE indexname = 'ix_escolas_geometry') = 1 as indice_geometria,
      COUNT(*) FILTER (WHERE indexname = 'pk_escolas') = 1 as primary_key
  FROM pg_indexes 
  WHERE schemaname = 'clean' AND tablename = 'escolas';

ROLLBACK;
