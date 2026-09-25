-- Verify edumaps:gestor_access_role from pg
BEGIN;

  SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
  FROM information_schema.columns
  WHERE table_schema = 'clean' AND table_name = 'gestores' AND column_name = 'access_role';

ROLLBACK;