-- Verify edumaps:censo_data_dictionary on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'censo_data_dictionary';

-- 2) Colunas obrigatórias existem e não são nulas
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'censo_data_dictionary'
  AND column_name IN (
    'table_name', 'column_name', 'data_type', 'year_introduced',
    'is_pk', 'is_fk'
  )
  AND is_nullable = 'NO';

-- 3) PK composta existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'censo_data_dictionary'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'censo_data_dictionary_pk';

-- 4) Pelo menos as 4 tabelas censo têm entradas
SELECT 1
FROM clean.censo_data_dictionary
WHERE table_name IN (
    'clean.censo_escolas',
    'clean.censo_matriculas',
    'clean.censo_docentes',
    'clean.censo_gestor'
)
GROUP BY table_name
HAVING COUNT(*) > 50;  -- cada tabela tem dezenas de colunas

-- 5) Domínios de valor (value_domain) preenchidos para tp_dependencia
SELECT 1
FROM clean.censo_data_dictionary
WHERE table_name IN ('clean.censo_escolas','clean.censo_matriculas','clean.censo_docentes','clean.censo_gestor')
  AND column_name = 'tp_dependencia'
  AND value_domain IS NOT NULL
  AND value_domain ? '1'  -- tem chave "1"
  AND value_domain ->> '1' = 'Federal';

-- 6) Colunas binárias in_* têm nota padrão
SELECT 1
FROM clean.censo_data_dictionary
WHERE column_name LIKE 'in_%'
  AND notes LIKE '%Binária 0/1%'
LIMIT 1;

-- 7) Metadados de proveniência registrados (pode ser NULL se Fase 0 não rodou)
--    Só verifica que as colunas existem
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'censo_data_dictionary'
  AND column_name IN ('source_url', 'source_license', 'retrieved_at');

ROLLBACK;