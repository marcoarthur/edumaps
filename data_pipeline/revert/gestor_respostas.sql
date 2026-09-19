-- Revert edumaps:gestor_respostas from pg

BEGIN;

  DROP TABLE clean.gestor_pesquisas_respostas_itens;
  DROP TABLE clean.gestor_pesquisas_respostas;
  DROP TABLE clean.sessoes;

  ALTER TABLE clean.gestores DROP COLUMN IF EXISTS senha_hash;

  ALTER TABLE clean.gestor_pesquisas DROP COLUMN IF EXISTS token;

COMMIT;