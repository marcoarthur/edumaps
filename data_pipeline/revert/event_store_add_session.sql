-- Revert edumaps:event_store_add_session from pg

BEGIN;

  ALTER TABLE event_store DROP COLUMN IF EXISTS session_id;
  ALTER TABLE event_store DROP COLUMN IF EXISTS gestor_id;

COMMIT;