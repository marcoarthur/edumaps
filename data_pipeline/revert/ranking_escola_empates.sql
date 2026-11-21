-- Revert edumaps:ranking_escola_empates from pg

BEGIN;

ALTER TABLE analytics.ranking_escola
  DROP COLUMN IF EXISTS empate_municipio,
  DROP COLUMN IF EXISTS empate_estado,
  DROP COLUMN IF EXISTS empate_nacional;

COMMIT;
