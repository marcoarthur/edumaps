-- Revert edumaps:relatorios_salvos_assistente from pg
--
-- IF EXISTS: reverter num banco parcialmente aplicado não aborta.

BEGIN;

  ALTER TABLE clean.relatorios_salvos DROP COLUMN IF EXISTS assistente;

COMMIT;
