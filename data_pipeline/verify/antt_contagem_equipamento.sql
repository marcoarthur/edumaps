-- Verify edumaps:antt_contagem_equipamento on pg
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
  IF to_regclass('clean.antt_contagem_equipamento') IS NULL THEN
    RETURN;
  END IF;
  SELECT count(*) INTO n FROM pg_attribute
   WHERE attrelid = 'clean.antt_contagem_equipamento'::regclass AND NOT attisdropped
     AND attname IN ('concessionaria','trecho','data_contagem','volume_diario','dt_snapshot');
  IF n <> 5 THEN
    RAISE EXCEPTION 'antt_contagem_equipamento: esperava 5 colunas, encontrei %', n;
  END IF;
END
$$;

ROLLBACK;
