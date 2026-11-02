-- Revert edumaps:gestores_email_unico_sem_caixa from pg

BEGIN;

DROP INDEX IF EXISTS clean.uq_gestores_email_lower;

COMMIT;
