-- Verify edumaps:analytics_mobilidade_escola on pg

BEGIN;

-- 1) View existe
SELECT 1
FROM information_schema.views
WHERE table_schema = 'analytics'
  AND table_name = 'mobilidade_escola';

-- 2) Colunas esperadas
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'mobilidade_escola'
  AND column_name IN ('co_entidade', 'no_entidade', 'codigo_ibge', 'municipio_escola', 'uf_escola', 'isocronas_por_tempo', 'antt_od_saida', 'renavam_total_frota', 'vmda_total_municipio', 'acidentes_12m', 'sinistros_12m')
  AND is_nullable = 'YES';

-- 3) View retorna linhas (se houver dados nas fontes)
SELECT 1
FROM analytics.mobilidade_escola
LIMIT 1;

-- 3) Colunas de indicadores derivados
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'mobilidade_escola'
  AND column_name IN ('pct_acidentes_fatais', 'pct_onibus_frota', 'status_isocrona', 'status_conexao_antt')
  AND is_nullable = 'YES';

ROLLBACK;