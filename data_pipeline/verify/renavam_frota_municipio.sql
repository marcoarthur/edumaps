-- Verify edumaps:renavam_frota_municipio on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'renavam_frota_municipio';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'renavam_frota_municipio'
  AND column_name IN ('codigo_ibge', 'ano', 'mes', 'total_frota', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renavam_frota_municipio'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_renavam_frota_municipio';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renavam_frota_municipio'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_renavam_frota_municipio';

-- 4) FK válida
SELECT 1
FROM clean.renavam_frota_municipio r
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = r.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.renavam_frota_municipio'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;