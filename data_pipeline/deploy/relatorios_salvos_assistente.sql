-- Deploy edumaps:relatorios_salvos_assistente to pg
-- requires: relatorios_salvos
--
-- Assistente de Relatório (issue #219 — Fase 4): os relatórios salvos passam
-- a registrar de qual assistente vieram. Change NOVA, anexada ao fim do
-- plano; relatorios_salvos (já deployada) não é editada.
--
-- Os salvos anteriores à Fase 4 foram todos gerados pelo assistente padrão
-- ("Relatório por tema"), daí o DEFAULT 'relatorio'. O título do assistente
-- não ganha coluna: vem da fotografia (conteudo->'assistente'->>'titulo').

BEGIN;

  ALTER TABLE clean.relatorios_salvos
    ADD COLUMN assistente text NOT NULL DEFAULT 'relatorio';

  COMMENT ON COLUMN clean.relatorios_salvos.assistente IS
    'Id do assistente que gerou o relatório (args do job); padrão relatorio (Relatório por tema)';

COMMIT;
