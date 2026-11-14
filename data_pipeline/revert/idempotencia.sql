-- Revert edumaps:idempotencia from pg

BEGIN;
  DROP TABLE clean.idempotencia;
COMMIT;
