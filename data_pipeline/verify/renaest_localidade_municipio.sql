-- Verify edumaps:renaest_localidade_municipio on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'renaest_localidade_municipio';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'renaest_localidade_municipio'
  AND column_name IN ('localidade', 'uf', 'codigo_ibge', 'nome_municipio', 'match_type', 'match_score', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renaest_localidade_municipio'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_renaest_localidade_municipio';

-- 3) FK para malha_municipio
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'renaest_localidade_municipio'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_renaest_depara_municipio';

-- 4) FK válida
SELECT 1
FROM clean.renaest_localidade_municipio r
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = r.codigo_ibge
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Match types válidos
SELECT 1
FROM clean.renaest_localidade_municipio
WHERE match_type NOT IN ('exact', 'fuzzy', 'manual')
LIMIT 1;

-- 6) Match score entre 0 e 100
SELECT 1
FROM clean.renaest_localidade_municipio
WHERE match_score < 0 OR match_score > 100
LIMIT 1;

-- 7) Seed exato populado (pelo menos 1000 municípios)
SELECT 1
FROM clean.renaest_localidade_municipio
WHERE match_type = 'exact'
HAVING COUNT(*) >= 1000;

-- 8) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.renaest_localidade_municipio'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;