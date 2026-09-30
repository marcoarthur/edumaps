-- Verify edumaps:snv_trecho_vmda on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'snv_trecho_vmda';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'snv_trecho_vmda'
  AND column_name IN ('concessionaria', 'trecho', 'codigo_ibge', 'vmda_total', 'geometry')
  AND is_nullable = 'NO';

-- 2) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'snv_trecho_vmda'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'snv_trecho_vmda_pkey';

-- 2) Unique constraint
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'snv_trecho_vmda'
  AND constraint_type = 'UNIQUE'
  AND constraint_name = 'uq_snv_trecho';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'snv_trecho_vmda'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_snv_trecho_municipio';

-- 4) FK válida (codigo_ibge nulo ou existe em malha_municipio)
SELECT 1
FROM clean.snv_trecho_vmda t
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = t.codigo_ibge
WHERE t.codigo_ibge IS NOT NULL AND m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Geometria válida
SELECT 1
FROM clean.snv_trecho_vmda
WHERE NOT ST_IsValid(geometry)
LIMIT 1;

-- 6) SRID correto (4674)
SELECT 1
FROM clean.snv_trecho_vmda
WHERE ST_SRID(geometry) != 4674
LIMIT 1;

-- 7) Metadados (inclui nota sobre decisão jurídica pendente)
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.snv_trecho_vmda'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL
  AND notes ILIKE '%decisão jurídica pendente%';

ROLLBACK;