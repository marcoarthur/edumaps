-- Deploy edumaps:planos_custo_executado to pg
-- requires: rede_acesso
--
-- #395 (visão da rede, #375; achado P2-PG-06 das personas): a ação do plano
-- ganha o valor EXECUTADO e a data da execução, ao lado do custo previsto.
-- Sem valor executado não é R$ 0: fica NULL e o relatório conta à parte.

BEGIN;

  ALTER TABLE clean.planos_acoes
    ADD COLUMN custo_executado numeric CHECK (custo_executado IS NULL OR custo_executado >= 0),
    ADD COLUMN executado_em    date;

  COMMENT ON COLUMN clean.planos_acoes.custo_executado IS
    'Valor efetivamente gasto na ação (R$). NULL = não informado (não é zero). P2-PG-06.';
  COMMENT ON COLUMN clean.planos_acoes.executado_em IS
    'Data da execução do gasto (para prestação de contas por período).';

COMMIT;
