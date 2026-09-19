-- Revert edumaps:gestor_pesquisas from pg
-- requires: schemas

BEGIN;

  DROP TABLE IF EXISTS clean.gestor_pesquisas_perguntas;
  DROP TABLE IF EXISTS clean.gestor_pesquisas;
  DROP TABLE IF EXISTS clean.gestores;

COMMIT;