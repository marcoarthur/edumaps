-- Verify edumaps:mapbiomas_cobertura on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'mapbiomas_cobertura';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'mapbiomas_cobertura'
  AND column_name IN ('codigo_ibge', 'ano', 'colecao', 'classe', 'area_ha')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'mapbiomas_cobertura'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_mapbiomas_cobertura';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'mapbiomas_cobertura'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_mapbiomas_municipio';

-- 5) Coleção fixa (collection9) - não por ano
SELECT 1
FROM clean.mapbiomas_cobertura
WHERE colecao = 'collection9'
LIMIT 1;

-- 6) Classes principais existem
SELECT 1
FROM clean.mapbiomas_cobertura
WHERE classe IN ('3', '4', '3.1', '3.2', '3.3', '4.1', '4.2', '5', '6')
GROUP BY classe
HAVING COUNT(*) > 100;

-- 7) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.mapbiomas_cobertura'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;