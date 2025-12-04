-- Revert edumaps:ideb_despivot from pg

-- Revert escola:inep_notas_desagregadas from pg
BEGIN;

  -- Remove índices
  DROP INDEX IF EXISTS clean.idx_inep_notas_escola_ano;
  DROP INDEX IF EXISTS clean.idx_inep_notas_uf;
  DROP INDEX IF EXISTS clean.idx_inep_notas_rede;
  DROP INDEX IF EXISTS clean.idx_inep_notas_municipio;
  DROP INDEX IF EXISTS clean.idx_inep_notas_ano;

  -- Remove a tabela
  DROP TABLE IF EXISTS clean.inep_notas_desagregadas;

COMMIT;
