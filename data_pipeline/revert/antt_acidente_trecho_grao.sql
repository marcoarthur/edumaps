-- Revert edumaps:antt_acidente_trecho_grao from pg

BEGIN;

ALTER TABLE clean.antt_acidente_trecho
  DROP CONSTRAINT uq_antt_acidente;

ALTER TABLE clean.antt_acidente_trecho
  ADD CONSTRAINT uq_antt_acidente
  UNIQUE (concessionaria, data_acidente, km, trecho);

ALTER TABLE clean.antt_acidente_trecho
  DROP COLUMN n_ocorrencia,
  DROP COLUMN horario;

COMMIT;
