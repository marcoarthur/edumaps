-- Revert edumaps:app_config from pg
BEGIN;

  DROP SCHEMA IF EXISTS app_config CASCADE;

  DROP EXTENSION IF EXISTS pgcrypto;

COMMIT;