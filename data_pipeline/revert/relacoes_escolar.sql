-- Revert edumaps:relacoes_escolar from pg

BEGIN;

  DROP TABLE clean.relacoes;
  DROP TABLE clean.relacoes_entidades;
  DROP TABLE clean.relacoes_categorias;

COMMIT;
