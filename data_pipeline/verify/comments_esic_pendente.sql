-- Verify edumaps:comments_esic_pendente on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION): um SELECT preguiçoso
-- devolve 'f' e o Sqitch 1.6.1 reporta 'ok' (issue #160). Um comment sem a
-- declaração de "NÃO CARREGADA" derruba a verificação.

BEGIN;

DO $$
DECLARE
  c TEXT;
BEGIN
  SELECT obj_description('clean.censo2022_setor'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CARREGADA' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_esic_pendente: censo2022_setor sem comment honesto (fonte não carregada declarada)';
  END IF;

  SELECT obj_description('clean.malha_setor_censitario'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CARREGADA' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_esic_pendente: malha_setor_censitario sem comment honesto (fonte não carregada declarada)';
  END IF;

  SELECT obj_description('clean.sisab_aps'::regclass) INTO c;
  IF c IS NULL OR position('NÃO CARREGADA' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_esic_pendente: sisab_aps sem comment honesto (fonte não carregada declarada)';
  END IF;
END $$;

ROLLBACK;