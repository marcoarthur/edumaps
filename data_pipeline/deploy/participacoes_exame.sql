-- Deploy edumaps:participacoes_exame to pg
-- requires: censo_escolar_2025

BEGIN;

  ALTER TABLE clean.censo_escolas 
  ADD COLUMN nro_participacoes_exame INTEGER NOT NULL DEFAULT 0;
  UPDATE clean.censo_escolas ce

  SET nro_participacoes_exame = sub.cnt
  FROM (
      SELECT id_escola, COUNT(*) AS cnt
      FROM clean.ideb_notas_escolas
      GROUP BY id_escola
  ) sub
  WHERE ce.co_entidade = sub.id_escola;

  COMMENT ON COLUMN clean.censo_escolas.nro_participacoes_exame IS 'Número de exames nacionais já realizados';

COMMIT;
