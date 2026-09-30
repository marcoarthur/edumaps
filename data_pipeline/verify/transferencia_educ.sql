-- Verify edumaps:transferencia_educ on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'transferencia_educ';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'transferencia_educ'
  AND column_name IN ('codigo_ibge', 'programa', 'valor_transferido', 'data_inicio', 'data_fim', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'transferencia_educ'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_transferencia_educ';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'transferencia_educ'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_transferencia_educ_municipio';

-- 4) FK válida
SELECT 1
FROM clean.transferencia_educ t
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = t.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Programas conhecidos existem
SELECT 1
FROM clean.transferencia_educ
WHERE programa IN ('FUNDEB', 'PNATE', 'PROINFANCIA', 'PDDE')
GROUP BY programa
HAVING COUNT(*) > 0
LIMIT 1;

-- 6) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.transferencia_educ'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;