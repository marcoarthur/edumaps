-- Revert edumaps:planos_alertas from pg

BEGIN;
  DROP TABLE clean.planos_alertas_envio;
COMMIT;
