-- Revert edumaps:gestor_access_role from pg
BEGIN;

  ALTER TABLE clean.gestores DROP COLUMN IF EXISTS access_role;

COMMIT;