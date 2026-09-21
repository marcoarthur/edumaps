-- Revert edumaps:relacoes_gestao from pg

BEGIN;

  DROP TABLE clean.relacoes_documentos;
  DROP TABLE clean.relacoes_interacoes;

COMMIT;
