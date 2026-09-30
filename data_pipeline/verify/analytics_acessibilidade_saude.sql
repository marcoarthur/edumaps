-- Verify edumaps:analytics_acessibilidade_saude on pg

BEGIN;

-- 1) View existe
SELECT 1
FROM information_schema.views
WHERE table_schema = 'analytics'
  AND table_name = 'acessibilidade_saude';

-- 2) Colunas esperadas
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'acessibilidade_saude'
  AND column_name IN ('co_entidade', 'codigo_ibge', 'dist_min_km_ubs', 'cobertura_aps', 'classificacao_acesso', 'efetividade_vagas_aps')
  AND is_nullable = 'YES';

-- 3) Join CNES/SISAB/Censo funciona (se houver dados)
-- Se não houver dados nas tabelas fonte, a view deve existir mas retornar 0 linhas
SELECT 1
FROM analytics.acessibilidade_saude
LIMIT 1;

ROLLBACK;