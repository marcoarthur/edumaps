-- Revert edumaps:analytics_esforco_fiscal from pg

BEGIN;

DROP VIEW IF EXISTS analytics.esforco_fiscal_educacao;

COMMIT;