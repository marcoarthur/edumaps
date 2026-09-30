-- Verify edumaps:analytics_esforco_fiscal on pg

BEGIN;

-- 1) View existe
SELECT 1
FROM information_schema.views
WHERE table_schema = 'analytics'
  AND table_name = 'esforco_fiscal_educacao';

-- 2) Colunas esperadas
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'esforco_fiscal_educacao'
  AND column_name IN ('codigo_ibge', 'nome_municipio', 'exercicio', 'fundeb_por_aluno', 'despesa_educ_por_aluno', 'pct_receita_em_educ', 'autonomia_fiscal_pct', 'dependencia_fundeb_pct', 'dependencia_federal_pct')
  AND is_nullable = 'YES';

-- 3) Join com malha_municipio funciona
SELECT 1
FROM analytics.esforco_fiscal_educacao e
JOIN clean.malha_municipio m ON m.codigo_ibge = e.codigo_ibge
LIMIT 1;

-- 4) Indicadores calculados (se houver dados nas fontes)
SELECT 1
FROM analytics.esforco_fiscal_educacao
WHERE fundeb_por_aluno IS NOT NULL
   OR despesa_educ_por_aluno IS NOT NULL
   OR pct_receita_em_educ IS NOT NULL
   OR autonomia_fiscal_pct IS NOT NULL
LIMIT 1;

-- 5) Metadados das tabelas fonte
SELECT 1
FROM clean.import_metadata
WHERE table_name IN ('clean.siconfi_receita', 'clean.siconfi_despesa', 'clean.transferencia_educ')
  AND source_url IS NOT NULL
  AND source_license IS NOT NULL
  AND retrieved_at IS NOT NULL;

ROLLBACK;