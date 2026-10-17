-- Deploy edumaps:censo2022_setor_renda_responsavel to pg
-- requires: censo2022_setor
-- requires: comments_ingestao_p2
--
-- #238 (revisto a 2026-10-17): a decisão "rendimento não é publicado por
-- setor" estava INCOMPLETA. Os Agregados por Setores realmente não trazem
-- renda, mas o IBGE publica a RENDA DO RESPONSÁVEL num produto IRMÃO:
--
--   Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/
--     Agregados_por_setores_renda_responsavel_BR_20260508_csv.zip
--     dicionario_de_dados_renda_responsavel_20260508.xlsx
--
-- Variáveis (rendimento nominal mensal do responsável, R$; o CSV usa PONTO
-- como separador decimal, diferente dos demais temas — ver o loader):
--   V06001 responsáveis em DPPO ocupados (o peso da arealização)
--   V06004 rendimento MÉDIO mensal do responsável
--   V06006 rendimento MEDIANO mensal do responsável
--
-- Por isso `rend_media` (V06004) deixa de ser "sem fonte"; `rend_mediana` e
-- `rend_resp_count` são novas. Per capita NÃO é publicado por setor: o produto
-- é do responsável, não da população — `rend_per_capita` continua NULL.
--
-- Vazio ≠ zero (#154): a célula "X" do IBGE vira NULL e marca
-- supressao_celula_pequena no setor — nunca 0.

BEGIN;

ALTER TABLE clean.censo2022_setor
  ADD COLUMN IF NOT EXISTS rend_mediana    NUMERIC,
  ADD COLUMN IF NOT EXISTS rend_resp_count INTEGER;

COMMENT ON COLUMN clean.censo2022_setor.rend_media IS
  'Rendimento nominal médio mensal do responsável (R$), IBGE V06004 — produto Rendimento_do_Responsavel (não é per capita).';
COMMENT ON COLUMN clean.censo2022_setor.rend_mediana IS
  'Rendimento nominal mediano mensal do responsável (R$), IBGE V06006 — produto Rendimento_do_Responsavel.';
COMMENT ON COLUMN clean.censo2022_setor.rend_resp_count IS
  'Pessoas responsáveis em DPPO ocupados (IBGE V06001) — peso da arealização da renda.';
COMMENT ON COLUMN clean.censo2022_setor.rend_per_capita IS
  'Sem fonte: o Censo 2022 por setor NÃO publica rendimento per capita (o produto de renda é do RESPONSÁVEL). NULL por desenho.';

COMMIT;
