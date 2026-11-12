-- Revert edumaps:planos_custo_executado from pg

BEGIN;
  ALTER TABLE clean.planos_acoes DROP COLUMN executado_em, DROP COLUMN custo_executado;
COMMIT;
