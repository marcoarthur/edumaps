-- Revert edumaps:session_tracking from pg

BEGIN;

  DROP TABLE IF EXISTS session_tracking CASCADE;

COMMIT;