-- Revert edumaps:health_check from pg

BEGIN;

  DROP FUNCTION health_check_approx(schema_name TEXT, table_name TEXT);

COMMIT;
