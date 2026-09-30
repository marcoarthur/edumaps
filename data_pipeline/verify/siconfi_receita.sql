-- Verify edumaps:siconfi_receita on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_receita';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_receita'
  AND column_name IN ('codigo_ibge', 'exercicio', 'tipo_receita', 'coluna_receita', 'valor', 'classificacao', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_receita'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_siconfi_receita';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_receita'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_siconfi_receita_municipio';

-- 5) FK válida
SELECT 1
FROM clean.siconfi_receita r
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = r.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 6) Classificação tem 'realizada' e 'estimativa'
SELECT 1
FROM clean.siconfi_receita
WHERE classificacao IN ('realizada', 'estimativa')
GROUP BY classificacao
HAVING COUNT(*) > 0
LIMIT 1;

-- 7) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.siconfi_receita'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;