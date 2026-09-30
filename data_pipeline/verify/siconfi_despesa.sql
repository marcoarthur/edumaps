-- Verify edumaps:siconfi_despesa on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_despesa';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_despesa'
  AND column_name IN ('codigo_ibge', 'exercicio', 'funcao', 'subfuncao', 'coluna_despesa', 'valor_pago', 'classificacao', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_despesa'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_siconfi_despesa';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'siconfi_despesa'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_siconfi_despesa_municipio';

-- 4) FK válida
SELECT 1
FROM clean.siconfi_despesa d
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = d.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Função 12 (Educação) existe
SELECT 1
FROM clean.siconfi_despesa
WHERE funcao = 12
LIMIT 1;

-- 6) Subfunções de educação existem
SELECT 1
FROM clean.siconfi_despesa
WHERE subfuncao IN (361, 362, 363, 364, 365)
GROUP BY subfuncao
HAVING COUNT(*) > 0
LIMIT 1;

-- 7) Classificação tem 'realizada' e 'estimativa'
SELECT 1
FROM clean.siconfi_despesa
WHERE classificacao IN ('realizada', 'estimativa')
GROUP BY classificacao
HAVING COUNT(*) > 0
LIMIT 1;

-- 8) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.siconfi_despesa'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;