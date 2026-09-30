-- Verify edumaps:isocrona_escolar on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'isocrona_escolar';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'isocrona_escolar'
  AND column_name IN ('codigo_ibge', 'co_entidade', 'tempo_minutos', 'grid_id', 'tileset_origin', 'engine', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'isocrona_escolar'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_isocrona_escolar';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'isocrona_escolar'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_isocrona_municipio';


SELECT 1
FROM clean.isocrona_escolar i
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = i.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Engine válido
SELECT 1
FROM clean.isocrona_escolar
WHERE engine IN ('osrm', 'valhalla')
LIMIT 1;

-- 6) Tileset_build_date não nulo
SELECT 1
FROM clean.isocrona_escolar
WHERE tileset_build_date IS NOT NULL
LIMIT 1;

-- 6) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.isocrona_escolar'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;