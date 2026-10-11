-- Revert edumaps:canal_listas_autoinscricao from pg
--
-- Ordem inversa de dependência: inscrições (referencia qrcodes, listas e
-- contatos) -> membros (referencia listas e contatos) -> qrcodes (referencia
-- listas e gestores) -> listas. IF EXISTS: reverter num banco parcialmente
-- aplicado não aborta o restante.

BEGIN;

  DROP TABLE IF EXISTS clean.canal_inscricoes;
  DROP TABLE IF EXISTS clean.canal_lista_membros;
  DROP TABLE IF EXISTS clean.canal_qrcodes;
  DROP TABLE IF EXISTS clean.canal_listas;

COMMIT;