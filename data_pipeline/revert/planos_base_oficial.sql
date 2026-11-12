-- Revert edumaps:planos_base_oficial from pg

BEGIN;
  ALTER TABLE clean.planos_metas DROP COLUMN linha_base_oficial;
COMMIT;
