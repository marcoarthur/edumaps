-- Revert edumaps:auth_falhas from pg

BEGIN;

DROP TABLE IF EXISTS clean.auth_falhas;

COMMIT;
