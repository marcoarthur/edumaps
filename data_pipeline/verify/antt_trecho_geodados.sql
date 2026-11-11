-- Verify edumaps:antt_trecho_geodados on pg
--
-- A tabela foi removida pela change posterior antt_sem_fonte (#168: a ANTT
-- não publica o dado para o qual ela foi desenhada). Num banco em que a
-- remoção já foi aplicada, não há o que verificar aqui — quem garante a
-- ausência é verify/antt_sem_fonte.sql. Antes dela, confere a tabela.
-- (DO + RAISE: o sqitch só falha a verificação com erro.)

BEGIN;

DO $$
DECLARE
  n integer;
BEGIN
  IF to_regclass('clean.antt_trecho_geodados') IS NULL THEN
    RETURN;
  END IF;
  SELECT count(*) INTO n FROM pg_attribute
   WHERE attrelid = 'clean.antt_trecho_geodados'::regclass AND NOT attisdropped
     AND attname IN ('concessionaria','trecho','codigo_ibge','geometry');
  IF n <> 4 THEN
    RAISE EXCEPTION 'antt_trecho_geodados: esperava 4 colunas, encontrei %', n;
  END IF;
END
$$;

ROLLBACK;
