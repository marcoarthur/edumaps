-- Revert edumaps:planos_indicadores from pg

BEGIN;

  DROP TABLE clean.planos_metas_medicoes;
  ALTER TABLE clean.planos_metas DROP CONSTRAINT fk_planos_metas_indicador;
  DROP VIEW analytics.escola_indicadores_meta;
  DROP TABLE analytics.indicadores_meta_catalogo;

COMMIT;
