-- Verify edumaps:inmet_alerta on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'inmet_alerta';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'inmet_alerta'
  AND column_name IN ('id_alerta', 'codigo_ibge', 'uf', 'data_inicio', 'severidade')
  AND is_nullable = 'NO';

-- 2) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'inmet_alerta'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_inmet_alerta';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'inmet_alerta'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_inmet_alerta_municipio';

-- 4) FK válida: todos os codigo_ibge existem em malha_municipio
SELECT 1
FROM clean.inmet_alerta i
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = i.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.inmet_alerta'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;