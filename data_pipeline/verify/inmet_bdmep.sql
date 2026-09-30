-- Verify edumaps:inmet_bdmep on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'inmet_bdmep';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'inmet_bdmep'
  AND column_name IN ('codigo_estacao', 'data', 'precipitacao_mm', 'temp_ar_max_c', 'temp_ar_min_c')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'inmet_bdmep'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_inmet_bdmep';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'inmet_bdmep'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_inmet_bdmep_municipio';

-- 3) FK válida (código_ibge nulo ou existe em malha_municipio)
SELECT 1
FROM clean.inmet_bdmep i
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = i.codigo_ibge
WHERE i.codigo_ibge IS NOT NULL AND m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Série com 26 anos (aprox 9.5k dias por estação)
SELECT 1
FROM clean.inmet_bdmep
GROUP BY codigo_estacao
HAVING COUNT(*) > 8000
LIMIT 1;

-- 6) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.inmet_bdmep'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;