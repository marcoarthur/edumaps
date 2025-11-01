-- Verify edumaps:raw_populacao on pg

BEGIN;

  -- Verificar se as tabelas foram criadas
  SELECT 1/count(*) FROM information_schema.tables 
  WHERE table_schema = 'raw' AND table_name = 'populacao_raw';

  SELECT 1/count(*) FROM information_schema.tables 
  WHERE table_schema = 'clean' AND table_name = 'populacao_municipal';

  -- Verificar transformações - agora usando varchar(7)
  SELECT 1 FROM clean.populacao_municipal 
  WHERE codigo_ibge = '1100015' AND nome_municipio = 'Alta Floresta D''Oeste';

  -- Verificar que registros com 'NA' foram convertidos para NULL
  SELECT 1 FROM clean.populacao_municipal 
  WHERE populacao_estimada IS NULL LIMIT 1;

ROLLBACK;
