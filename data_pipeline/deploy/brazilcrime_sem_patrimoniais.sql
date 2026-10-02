-- Deploy edumaps:brazilcrime_sem_patrimoniais to pg
-- requires: brazilcrime_contrato_sinesp

BEGIN;

-- =================================================================
-- REMOÇÃO DAS COLUNAS DE CRIMES PATRIMONIAIS
-- Issue #164
--
-- Medido: o pacote BrazilCrime 0.3.0 NÃO publica crimes patrimoniais
-- (roubo, furto) por município. A categoria "ocorrencias" tem 13 452
-- linhas, mas TODAS com municipio == "NÃO INFORMADO".
--
-- As 4 colunas roubo_veiculo, roubo_carga, roubo_instituicao_financeira
-- e furto_veiculo ficam permanentemente vazias. Uma coluna que nunca
-- tem valor não é um contrato, é ruído — e o consumidor deixa de
-- poder estragá-la.
-- =================================================================

ALTER TABLE clean.brazilcrime_municipio
  DROP COLUMN IF EXISTS roubo_veiculo,
  DROP COLUMN IF EXISTS roubo_carga,
  DROP COLUMN IF EXISTS roubo_instituicao_financeira,
  DROP COLUMN IF EXISTS furto_veiculo;

COMMENT ON TABLE clean.brazilcrime_municipio IS
  'Criminalidade agregada por município/ano. Fonte: SINESP VDE (violência letal), empacotado no pacote R BrazilCrime 0.3.0 (CRAN) — ver issue #164. '
  'ATENÇÃO: os dados são um snapshot embutido no pacote, congelado na versão publicada; não há sincronização automática com o SINESP. '
  'O grão por município/ano é o máximo que a fonte permite: NÃO expor por escola, nem agregada. '
  'Supressão de célula pequena (count < 5) obrigatória, sinalizada em supressao_celula_pequena — que NÃO é zero. '
  'Municípios que a fonte não cobre ficam com NULL, nunca com 0. '
  'Crimes patrimoniais (roubo, furto) NÃO estão disponíveis por município na fonte — ver issue #164.';

COMMIT;
