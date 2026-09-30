-- Verify edumaps:sisab_aps on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'sisab_aps';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'sisab_aps'
  AND column_name IN ('codigo_municipio', 'dt_referencia', 'dt_snapshot', 'cobertura_aps', 'ativas_ff', 'equipe_esf', 'equipe_emsi', 'categoria_ivs')
  AND is_nullable = 'NO';

-- 3) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'sisab_aps'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_sisab_aps';

-- 4) FK implícita: codigo_municipio existe em malha_municipio
SELECT 1
FROM clean.sisab_aps s
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = s.codigo_municipio
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 5) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.sisab_aps'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;