-- Revert edumaps:canal_envios from pg
--
-- Ordem inversa das dependências (FKs). IF EXISTS: reverter num banco
-- parcialmente aplicado não aborta o restante.

BEGIN;

  DROP TABLE IF EXISTS clean.canal_envio_suspensoes;
  DROP TABLE IF EXISTS clean.canal_qr_acessos;
  DROP TABLE IF EXISTS clean.canal_optouts;
  DROP TABLE IF EXISTS clean.canal_envio_destinatarios;
  DROP TABLE IF EXISTS clean.canal_envios;
  DROP TABLE IF EXISTS clean.canal_segmentos;

COMMIT;
