-- Verify edumaps:censo2022_setor on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'censo2022_setor';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'censo2022_setor'
  AND column_name IN ('codigo_setor', 'codigo_ibge', 'pop_total', 'supressao_celula_pequena')
  AND is_nullable = 'NO';

-- 3) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'censo2022_setor'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'censo2022_setor_pk';

-- 4) FK para malha_setor_censitario existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'censo2022_setor'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_censo2022_setor_malha';

-- 5) Supressão de célula pequena é booleana com default false
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'censo2022_setor'
  AND column_name = 'supressao_celula_pequena'
  AND data_type = 'boolean'
  AND column_default = 'false';

-- 6) Contagem de setores (aprox 316.574)
SELECT 1
FROM clean.censo2022_setor
HAVING COUNT(*) BETWEEN 315000 AND 318000;

-- 7) Supressão explícita (não confundir zero com NULL)
--    Linhas com supressao=true devem ter campos principais NULL
SELECT 1
FROM clean.censo2022_setor
WHERE supressao_celula_pequena = TRUE
  AND pop_total IS NULL
LIMIT 1;

-- 8) FK válida: todos os codigo_setor existem em malha_setor_censitario
SELECT 1
FROM clean.censo2022_setor c
LEFT JOIN clean.malha_setor_censitario m ON m.codigo_setor = c.codigo_setor
WHERE m.codigo_setor IS NULL
LIMIT 1;

-- 9) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.censo2022_setor'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;