-- Verify edumaps:recife_transporte_escolar on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'recife_transporte_escolar';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'recife_transporte_escolar'
  AND column_name IN ('co_entidade', 'ano', 'vagas_transporte', 'turno', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'recife_transporte_escolar'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_recife_transporte_escolar';


SELECT 1
FROM clean.recife_transporte_escolar r
LEFT JOIN clean.censo_escolas e ON e.co_entidade = r.co_entidade
WHERE e.co_entidade IS NULL
LIMIT 1;

-- 5) Licença ODbL registrada nos metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.recife_transporte_escolar'
  AND source_license ILIKE '%odbl%'
  AND notes ILIKE '%share-alike%'
  AND notes ILIKE '%jurídico%';

ROLLBACK;