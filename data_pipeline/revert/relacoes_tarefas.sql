-- Revert edumaps:relacoes_tarefas from pg

BEGIN;

  DROP TABLE clean.relacoes_tarefas;

COMMIT;
