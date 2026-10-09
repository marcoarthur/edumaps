-- Verify edumaps:comments_inmet_mapbiomas_pendente on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION): um SELECT preguiçoso
-- devolve 'f' e o Sqitch 1.6.1 reporta 'ok' (issue #160). Um comment sem a
-- declaração "NÃO CONSTRUÍDA" — ou sem a referência à decisão/issue que a
-- originou — derruba a verificação.

BEGIN;

DO $$
DECLARE
  c TEXT;
BEGIN
  SELECT obj_description('clean.inmet_bdmep'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CONSTRUÍDA' IN c) = 0 OR position('#171' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_inmet_mapbiomas_pendente: inmet_bdmep sem declaração NÃO CONSTRUÍDA/decisão #171';
  END IF;

  SELECT obj_description('clean.inmet_alerta'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CONSTRUÍDA' IN c) = 0 OR position('#171' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_inmet_mapbiomas_pendente: inmet_alerta sem declaração NÃO CONSTRUÍDA/decisão #171';
  END IF;

  SELECT obj_description('clean.mapbiomas_cobertura'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CONSTRUÍDA' IN c) = 0 OR position('#170' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_inmet_mapbiomas_pendente: mapbiomas_cobertura sem declaração NÃO CONSTRUÍDA/#170';
  END IF;
END $$;

ROLLBACK;
