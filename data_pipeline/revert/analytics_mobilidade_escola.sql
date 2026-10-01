-- Revert edumaps:analytics_mobilidade_escola from pg

BEGIN;

DROP VIEW IF EXISTS analytics.mobilidade_escola;

COMMIT;