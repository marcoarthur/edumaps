-- Verify edumaps:antt_acidente_trecho on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'antt_acidente_trecho';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'antt_acidente_trecho'
  AND column_name IN ('id_acidente', 'concessionaria', 'data_acidente', 'km', 'trecho', 'mortos', 'feridos_graves', 'feridos_leves')
  AND is_nullable = 'NO';

-- 2) PK existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_acidente_trecho'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'antt_acidente_trecho_pkey';

-- 3) Unique constraint na chave bruta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_acidente_trecho'
  AND constraint_type = 'UNIQUE'
  AND constraint_name = 'uq_antt_acidente';

-- 4) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.antt_acidente_trecho'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;