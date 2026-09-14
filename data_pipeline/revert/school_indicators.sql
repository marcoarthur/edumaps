-- Revert edumaps:school_indicators from pg

BEGIN;

  DROP TABLE IF EXISTS clean.school_indicators;

COMMIT;