-- Verify edumaps:mapbiomas_risco_carbono_nodata on pg
--
-- DO/RAISE EXCEPTION (issue #160): tem de falhar mesmo quando o estado está
-- errado. Falha se ainda houver carbono negativo ou se o comentário da
-- regra #154 não estiver na coluna.

BEGIN;

DO $$
DECLARE
  c      BIGINT;
  texto  TEXT;
BEGIN
  SELECT count(*) INTO c
    FROM clean.mapbiomas_escola_risco
   WHERE solo_carbono_medio < 0;

  IF c > 0 THEN
    RAISE EXCEPTION
      'mapbiomas_risco_carbono_nodata: % linha(s) ainda com solo_carbono_medio negativo (nodata sem mascarar)',
      c;
  END IF;

  texto := col_description('clean.mapbiomas_escola_risco'::regclass,
                           (SELECT attnum FROM pg_attribute
                             WHERE attrelid = 'clean.mapbiomas_escola_risco'::regclass
                               AND attname = 'solo_carbono_medio'));

  IF texto IS NULL OR position('#154' IN texto) = 0 THEN
    RAISE EXCEPTION
      'mapbiomas_risco_carbono_nodata: comentário da coluna sem a marca da regra #154: %',
      texto;
  END IF;
END $$;

ROLLBACK;
