-- Verify edumaps:cnes_estabelecimentos on pg

BEGIN;

-- 1) Tabela existe
SELECT 1
FROM information_schema.tables
WHERE table_schema = 'clean'
  AND table_name = 'cnes_estabelecimentos';

-- 2) Colunas obrigatórias (sem PII)
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'cnes_estabelecimentos'
  AND column_name IN ('codigo_cnes', 'codigo_municipio', 'codigo_tipo_unidade', 'status', 'latitude', 'longitude', 'data_atualizacao', 'dt_snapshot')
  AND is_nullable = 'NO';

-- 3) PK composta existe
SELECT 1
FROM information_schema.table_constraints
WHERE table_schema = 'clean'
  AND table_name = 'cnes_estabelecimentos'
  AND constraint_type = 'PRIMARY KEY'
  AND constraint_name = 'pk_cnes_estabelecimentos';

-- 4) Colunas PII NÃO existem
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'clean'
  AND table_name = 'cnes_estabelecimentos'
  AND column_name IN ('nome_razao_social', 'nome_fantasia', 'numero_cnpj_entidade', 'numero_telefone_estabelecimento', 'endereco_email_estabelecimento', 'endereco_estabelecimento', 'bairro_estabelecimento')
  AND is_nullable = 'NO';

-- 5) Se houver dados, geometria válida
SELECT 1
FROM clean.cnes_estabelecimentos
WHERE latitude IS NOT NULL AND longitude IS NOT NULL
  AND NOT ST_IsValid(ST_SetSRID(ST_MakePoint(longitude, latitude), 4674))
LIMIT 1;

-- 6) FK implícita: codigo_municipio existe em malha_municipio
SELECT 1
FROM clean.cnes_estabelecimentos c
LEFT JOIN clean.malha_municipio m ON m.codigo_ibge = c.codigo_municipio
WHERE m.codigo_ibge IS NULL
LIMIT 1;

-- 7) Metadados de importação
SELECT 1
FROM clean.import_metadata
WHERE table_name = 'clean.cnes_estabelecimentos'
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;