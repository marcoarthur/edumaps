-- Verify edumaps:antt_od_municipio on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'antt_od_municipio';

-- 2) Colunas obrigatórias
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'antt_od_municipio'
  AND column_name IN ('codigo_ibge_origem', 'codigo_ibge_destino', 'mes_viagem', 'quantidade_bilhetes', 'supressao_aplicada', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 2) PK composta
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_od_municipio'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_antt_od_municipio';

-- 3) FKs para malha_municipio (origem e destino)
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'antt_od_municipio'
  AND constraint_type = 'FOREIGN KEY'
  AND constraint_name IN ('fk_antt_od_origem', 'fk_antt_od_destino');

-- 3) FKs válidas
SELECT 1
FROM clean.antt_od_municipio o
LEFT JOIN clean.malha_municipio m1 ON m1.codigo_ibge = o.codigo_ibge_origem
LEFT JOIN clean.malha_municipio m2 ON m2.codigo_ibge = o.codigo_ibge_destino
WHERE m1.codigo_ibge IS NULL OR m2.codigo_ibge IS NULL
LIMIT 1;

-- 4) Supressão aplicada é boolean
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'antt_od_municipio'
  AND column_name = 'supressao_aplicada'
  AND data_type = 'boolean'
  AND column_default = 'false';

-- 5) Metadados
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.antt_od_municipio'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;