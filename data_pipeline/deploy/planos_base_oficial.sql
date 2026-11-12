-- Deploy edumaps:planos_base_oficial to pg
-- requires: planos_evidencias
--
-- Achado P2-PG-05 da reavaliação das personas (2026-11-12), opção (b) do
-- developer: a escola pode ajustar a linha de base de uma meta oficial, mas o
-- ajuste fica visível. A meta guarda o valor OFICIAL da fonte no momento em
-- que nasce (ou em que passa a seguir um indicador); "base ajustada" = linha
-- de base diferente desse valor, calculada na aplicação.
--
-- Metas oficiais já existentes: o valor oficial de origem não foi guardado,
-- então o backfill assume que a base atual é a oficial (sem marca). Só as
-- mudanças daqui em diante aparecem como ajuste.

BEGIN;

  ALTER TABLE clean.planos_metas ADD COLUMN linha_base_oficial numeric;

  COMMENT ON COLUMN clean.planos_metas.linha_base_oficial IS
    'Valor oficial do indicador quando a meta passou a segui-lo (sugestão de linha de base). Linha de base diferente = ajustada pela escola, marcada na tela e no relatório (P2-PG-05).';

  UPDATE clean.planos_metas SET linha_base_oficial = linha_base
   WHERE indicador_codigo IS NOT NULL;

COMMIT;
