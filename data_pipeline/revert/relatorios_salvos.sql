-- Revert edumaps:relatorios_salvos from pg
--
-- IF EXISTS: reverter num banco parcialmente aplicado não aborta. O índice
-- cai junto com a tabela.

BEGIN;

  DROP TABLE IF EXISTS clean.relatorios_salvos;

COMMIT;
