-- Verify edumaps:renaest_sinistro on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'renaest_sinistro';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'renaest_sinistro'
  AND column_name IN ('localidade', 'uf', 'data_sinistro', 'mortos', 'feridos_graves', 'feridos_leves', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renaest_sinistro'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'renaest_sinistro_pkey';

-- 3) Unique constraint
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renaest_sinistro'
  AND constraint_type = 'UNIQUE'
  AND constraint_name = 'uq_renaest_sinistro';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renaest_sinistro'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_renaest_municipio';

-- 4) FK válida (codigo_ibge nulo ou existe em malha_municipio)
SELECT 1
FROM clean.renaest_sinistro r
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = r.codigo_ibge
WHERE r.codigo_ibge IS NOT NULL AND m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.renaest_sinistro'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;