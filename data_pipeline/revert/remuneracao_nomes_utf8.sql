-- Revert edumaps:remuneracao_nomes_utf8 from pg
--
-- Sem volta: o texto anterior era o defeito (#536). Reverter só tira a
-- change do registry.

BEGIN;
SELECT 1;
COMMIT;
