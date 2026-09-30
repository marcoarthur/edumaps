-- Verify edumaps:brazilcrime_municipio on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'brazilcrime_municipio';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'brazilcrime_municipio'
  AND column_name IN ('codigo_ibge', 'ano', 'homicidio_doloso', 'supressao_celula_pequena', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'brazilcrime_municipio'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_brazilcrime_municipio';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'brazilcrime_municipio'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_brazilcrime_municipio';

-- 4) FK válida
SELECT 1
FROM clean.brazilcrime_municipio b
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = b.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Supressão de célula pequena é boolean com default false
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'brazilcrime_municipio'
  AND column_name = 'supressao_celula_pequena'
  AND data_type = 'boolean'
  AND column_default = 'false';

-- 6) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.brazilcrime_municipio'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;