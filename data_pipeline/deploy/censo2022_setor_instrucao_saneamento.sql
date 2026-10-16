-- Deploy edumaps:censo2022_setor_instrucao_saneamento to pg
-- requires: censo2022_setor
--
-- #137: dá conteúdo ao bloco B (socioeconômico) do IVET. O Censo 2022 por
-- setor NÃO publica renda nem escolaridade 25+ (#238); publica alfabetização
-- 15+ e características do domicílio (água, esgoto, lixo, banheiro). Estas
-- colunas recebem as CONTAGENS CRUAS do IBGE por categoria (DPPO = domicílios
-- particulares permanentes ocupados); a classificação adequado/inadequado e as
-- proporções ficam na arealização (change escola_entorno_socioeconomico_saneamento),
-- não aqui.
--
-- Vazio ≠ zero (#154): a célula suprimida por sigilo ("X") do IBGE vira NULL e
-- marca supressao_celula_pequena no setor — nunca 0.
--
-- Fonte das variáveis (dicionário IBGE 20260520):
--   alfabetizacao:               V00900, V00901
--   caracteristicas_domicilio2:  V00111..V00118, V00309..V00316,
--                                V00397..V00402, V00494, V00495

BEGIN;

ALTER TABLE clean.censo2022_setor
  -- Alfabetização — pessoas de 15 anos ou mais
  ADD COLUMN IF NOT EXISTS alf_sabe_15mais               INTEGER,
  ADD COLUMN IF NOT EXISTS alf_nao_sabe_15mais           INTEGER,
  -- Água — forma de abastecimento (DPPO)
  ADD COLUMN IF NOT EXISTS dom_agua_rede                 INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_poco_profundo        INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_poco_raso            INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_nascente             INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_carro_pipa           INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_chuva                INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_rio                  INTEGER,
  ADD COLUMN IF NOT EXISTS dom_agua_outra                INTEGER,
  -- Esgoto — destinação (DPPO)
  ADD COLUMN IF NOT EXISTS dom_esgoto_rede               INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_fossa_septica_rede INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_fossa_septica      INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_fossa_rudimentar   INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_vala               INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_rio                INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_outra              INTEGER,
  ADD COLUMN IF NOT EXISTS dom_esgoto_inexistente        INTEGER,
  -- Lixo — destino (DPPO)
  ADD COLUMN IF NOT EXISTS dom_lixo_coletado             INTEGER,
  ADD COLUMN IF NOT EXISTS dom_lixo_cacamba              INTEGER,
  ADD COLUMN IF NOT EXISTS dom_lixo_queimado             INTEGER,
  ADD COLUMN IF NOT EXISTS dom_lixo_enterrado            INTEGER,
  ADD COLUMN IF NOT EXISTS dom_lixo_jogado               INTEGER,
  ADD COLUMN IF NOT EXISTS dom_lixo_outro                INTEGER,
  -- Banheiro (DPPO): com/sem banheiro de uso exclusivo com chuveiro e vaso
  ADD COLUMN IF NOT EXISTS dom_banheiro_exclusivo        INTEGER,
  ADD COLUMN IF NOT EXISTS dom_sem_banheiro              INTEGER;

COMMENT ON COLUMN clean.censo2022_setor.alf_sabe_15mais IS
  'Pessoas de 15+ anos que sabem ler e escrever (IBGE V00900).';
COMMENT ON COLUMN clean.censo2022_setor.alf_nao_sabe_15mais IS
  'Pessoas de 15+ anos que não sabem ler e escrever (IBGE V00901).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_rede IS
  'DPPO que utilizam rede geral de distribuição de água (IBGE V00111).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_poco_profundo IS
  'DPPO que utilizam poço profundo ou artesiano (IBGE V00112).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_poco_raso IS
  'DPPO que utilizam poço raso, freático ou cacimba (IBGE V00113).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_nascente IS
  'DPPO que utilizam fonte, nascente ou mina (IBGE V00114).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_carro_pipa IS
  'DPPO que utilizam carro-pipa (IBGE V00115).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_chuva IS
  'DPPO que utilizam água da chuva armazenada (IBGE V00116).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_rio IS
  'DPPO que utilizam rios, açudes, córregos, lagos e igarapés (IBGE V00117).';
COMMENT ON COLUMN clean.censo2022_setor.dom_agua_outra IS
  'DPPO que utilizam outra forma de abastecimento de água (IBGE V00118).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_rede IS
  'DPPO cujo esgoto vai para rede geral ou pluvial (IBGE V00309).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_fossa_septica_rede IS
  'DPPO com fossa séptica/filtro ligada à rede (IBGE V00310).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_fossa_septica IS
  'DPPO com fossa séptica/filtro não ligada à rede (IBGE V00311).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_fossa_rudimentar IS
  'DPPO cujo esgoto vai para fossa rudimentar ou buraco (IBGE V00312).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_vala IS
  'DPPO cujo esgoto vai para vala (IBGE V00313).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_rio IS
  'DPPO cujo esgoto vai para rio, lago, córrego ou mar (IBGE V00314).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_outra IS
  'DPPO cujo esgoto tem outra destinação (IBGE V00315).';
COMMENT ON COLUMN clean.censo2022_setor.dom_esgoto_inexistente IS
  'DPPO sem esgoto: não tinham banheiro nem sanitário (IBGE V00316).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_coletado IS
  'DPPO cujo lixo é coletado no domicílio por serviço de limpeza (IBGE V00397).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_cacamba IS
  'DPPO cujo lixo é depositado em caçamba de serviço de limpeza (IBGE V00398).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_queimado IS
  'DPPO cujo lixo é queimado na propriedade (IBGE V00399).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_enterrado IS
  'DPPO cujo lixo é enterrado na propriedade (IBGE V00400).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_jogado IS
  'DPPO cujo lixo é jogado em terreno baldio, encosta ou área pública (IBGE V00401).';
COMMENT ON COLUMN clean.censo2022_setor.dom_lixo_outro IS
  'DPPO com outro destino do lixo (IBGE V00402).';
COMMENT ON COLUMN clean.censo2022_setor.dom_banheiro_exclusivo IS
  'DPPO com banheiro de uso exclusivo com chuveiro e vaso sanitário (IBGE V00494).';
COMMENT ON COLUMN clean.censo2022_setor.dom_sem_banheiro IS
  'DPPO sem banheiro de uso exclusivo (comum, só sanitário ou nenhum) (IBGE V00495).';

COMMIT;
