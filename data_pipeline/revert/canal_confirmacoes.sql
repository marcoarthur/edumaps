-- Revert edumaps:canal_confirmacoes from pg
--
-- Derruba a tabela de confirmação de posse de endereço de canal. Os índices
-- caem junto com a tabela. IF EXISTS: reverter num banco parcialmente aplicado
-- não aborta o restante.

BEGIN;

  DROP TABLE IF EXISTS clean.canal_confirmacoes;

COMMIT;
