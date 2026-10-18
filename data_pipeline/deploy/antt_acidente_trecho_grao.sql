-- Deploy edumaps:antt_acidente_trecho_grao to pg
-- requires: antt_acidente_trecho
--
-- #168: a chave única original (concessionaria, data_acidente, km, trecho) era
-- GROSSA DEMAIS. Medido no CSV real da RODOVIA DO AÇO (12.650 linhas): 79
-- acidentes partilham km+dia+trecho — dois eventos no mesmo ponto, em horários
-- diferentes. A carga falhava com "ON CONFLICT DO UPDATE command cannot affect
-- row a second time". O grão real do EVENTO é (concessionaria, data_acidente,
-- horario, n_ocorrencia): medido, 0 duplicados.
--
-- Change NOVA (a `antt_acidente_trecho` já estava deployada; editar o `requires`
-- ou reordenar changes deployadas quebra o `change_id` — ver AGENTS.md).

BEGIN;

ALTER TABLE clean.antt_acidente_trecho
  ADD COLUMN horario      TIME,
  ADD COLUMN n_ocorrencia TEXT;

ALTER TABLE clean.antt_acidente_trecho
  DROP CONSTRAINT uq_antt_acidente;

ALTER TABLE clean.antt_acidente_trecho
  ADD CONSTRAINT uq_antt_acidente
  UNIQUE (concessionaria, data_acidente, horario, n_ocorrencia);

COMMENT ON COLUMN clean.antt_acidente_trecho.horario IS
'Hora da ocorrência — parte da chave do evento (dois acidentes podem partilhar km/dia/trecho).';
COMMENT ON COLUMN clean.antt_acidente_trecho.n_ocorrencia IS
'Número da ocorrência na fonte — parte da chave do evento.';

COMMIT;
