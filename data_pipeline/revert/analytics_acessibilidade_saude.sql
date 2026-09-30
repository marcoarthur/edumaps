-- Revert edumaps:analytics_acessibilidade_saude from pg

BEGIN;

DROP VIEW IF EXISTS analytics.acessibilidade_saude;

COMMIT;