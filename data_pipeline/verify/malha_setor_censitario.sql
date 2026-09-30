-- Verify edumaps:malha_setor_censitario on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'malha_setor_censitario';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'malha_setor_censitario'
  AND column_name IN ('codigo_setor', 'codigo_ibge', 'geometry')
  AND is_nullable = 'NO';

-- 3) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'malha_setor_censitario'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_malha_setor_censitario';

-- 4) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'malha_setor_censitario'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_malha_setor_municipio';

-- 5) Geometria válida (se houver dados)
SELECT 1
FROM clean.malha_setor_censitario
WHERE NOT ST_IsValid(geometry)
LIMIT 1;

-- 6) SRID correto (4674) se houver dados
SELECT 1
FROM clean.malha_setor_censitario
WHERE ST_SRID(geometry) != 4674
LIMIT 1;

-- 7) FK válida: todos os codigo_ibge existem em malha_municipio
SELECT 1
FROM clean.malha_setor_censitario s
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = s.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 8) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.malha_setor_censitario'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;