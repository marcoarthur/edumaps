-- Revert edumaps:brazilcrime_sem_patrimoniais to pg
-- requires: brazilcrime_sem_patrimoniais

BEGIN;

ALTER TABLE clean.brazilcrime_municipio
  ADD COLUMN IF NOT EXISTS roubo_veiculo INTEGER,
  ADD COLUMN IF NOT EXISTS roubo_carga INTEGER,
  ADD COLUMN IF NOT EXISTS roubo_instituicao_financeira INTEGER,
  ADD COLUMN IF NOT EXISTS furto_veiculo INTEGER;

COMMENT ON TABLE clean.brazilcrime_municipio IS
  'Criminalidade agregada por município/ano. Fonte: SINESP VDE (violência letal e patrimonial), empacotado no pacote R BrazilCrime 0.3.0 (CRAN) — ver issue #164. '
  'ATENÇÃO: os dados são um snapshot embutido no pacote, congelado na versão publicada; não há sincronização automática com o SINESP. '
  'O grão por município/ano é o máximo que a fonte permite: NÃO expor por escola, nem agregada. '
  'Supressão de célula pequena (count < 5) obrigatória, sinalizada em supressao_celula_pequena — que NÃO é zero. '
  'Municípios que a fonte não cobre ficam com NULL, nunca com 0.';

COMMIT;
