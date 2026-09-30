-- Verify edumaps:ibge_agregados on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'ibge_agregados';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'ibge_agregados'
  AND column_name IN ('codigo_ibge', 'ano', 'tabela_id', 'variavel', 'valor')
  AND is_nullable = 'NO';

-- 3) PK composta existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'ibge_agregados'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'ibge_agregados_pk';

-- 2) View existe
SELECT 1
FROM information_schema.views
WHERE table_schema = 'clean'
  AND table_name = 'v_ibge_municipio_ano';

-- 3) Pelo menos alguns agregados conhecidos existem
SELECT 1
FROM clean.ibge_agregados
WHERE tabela_id IN ('1393', '6579', '1093', '5938')
GROUP BY tabela_id
HAVING COUNT(*) > 100;

-- 4) Chaves estrangeiras válidas (codigo_ibge existe em malha_municipio)
SELECT 1
FROM clean.ibge_agregados a
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = a.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.ibge_agregados'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;