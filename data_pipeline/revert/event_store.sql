-- Revert edumaps:event_store from pg

BEGIN;

  DROP TABLE IF EXISTS event_store CASCADE;

COMMIT;
