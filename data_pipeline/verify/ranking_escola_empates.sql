-- Verify edumaps:ranking_escola_empates on pg
-- Falha de verdade (RAISE), ver verify/analytics_ausencia_visivel.sql.

BEGIN;

DO $$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n
    FROM pg_attribute
   WHERE attrelid = 'analytics.ranking_escola'::regclass
     AND attname IN ('empate_municipio', 'empate_estado', 'empate_nacional')
     AND NOT attisdropped;
  IF n <> 3 THEN
    RAISE EXCEPTION 'analytics.ranking_escola sem as colunas de empate (#506): % de 3', n;
  END IF;
END $$;

ROLLBACK;
