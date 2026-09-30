-- Verify edumaps:antt_contagem_equipamento on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'antt_contagem_equipamento';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'antt_contagem_equipamento'
  AND column_name IN ('concessionaria', 'trecho', 'data_contagem', 'volume_diario', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_contagem_equipamento'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'antt_contagem_equipamento_pkey';

-- 3) Unique constraint
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_contagem_equipamento'
  AND constraint_type = 'UNIQUE'
  AND constraint_name = 'uq_antt_contagem';

-- 3) FK para antt_trecho_geodados
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_contagem_equipamento'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name = 'fk_antt_contagem_trecho';

-- 4) FK válida
SELECT 1
FROM clean.antt_contagem_equipamento c
LEFT JOIN clean.antt_trecho_geodados t ON t.trecho = c.trecho
WHERE t.trecho IS NULL
LIMIT 1;

-- 4) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.antt_contagem_equipamento'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;