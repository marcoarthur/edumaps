-- Verify edumaps:participacoes_exame on pg

BEGIN;

  SELECT co_entidade, no_entidade, nro_participacoes_exame
  FROM clean.censo_escolas
  WHERE nro_participacoes_exame > 0
  LIMIT 10;

ROLLBACK;
