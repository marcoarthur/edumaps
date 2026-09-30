-- Verify edumaps:malha_municipio on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'malha_municipio';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'malha_municipio'
  AND column_name IN ('codigo_ibge', 'nome_municipio', 'sigla_uf', 'area_km2', 'geometry')
  AND is_nullable = 'NO';

-- 3) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'malha_municipio'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_malha_municipio';

-- 4) Geometria válida
SELECT 1
FROM clean.malha_municipio
WHERE NOT ST_IsValid(geometry)
LIMIT 1;

-- 5) Contagem de municípios (5570)
SELECT 1
FROM clean.malha_municipio
HAVING COUNT(*) = 5570;

-- 6) SRID correto (4674)
SELECT 1
FROM clean.malha_municipio
WHERE ST_SRID(geometry) != 4674
LIMIT 1;

-- 7) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.malha_municipio'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL
  AND row_count_loaded = 5570;

ROLLBACK;