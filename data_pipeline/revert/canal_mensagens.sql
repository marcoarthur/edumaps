-- Revert edumaps:canal_mensagens from pg
--
-- Derruba a tabela de histórico de mensagens de canal. Os índices caem junto
-- com a tabela. IF EXISTS: reverter num banco parcialmente aplicado não aborta
-- o restante.

BEGIN;

  DROP TABLE IF EXISTS clean.canal_mensagens;

COMMIT;
