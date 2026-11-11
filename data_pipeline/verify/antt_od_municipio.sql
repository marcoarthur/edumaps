-- Verify edumaps:antt_od_municipio on pg
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
  IF to_regclass('clean.antt_od_municipio') IS NULL THEN
    RETURN;
  END IF;
  SELECT count(*) INTO n FROM pg_attribute
   WHERE attrelid = 'clean.antt_od_municipio'::regclass AND NOT attisdropped
     AND attname IN ('codigo_ibge_origem','codigo_ibge_destino','mes_viagem','quantidade_bilhetes','supressao_aplicada','dt_snapshot');
  IF n <> 6 THEN
    RAISE EXCEPTION 'antt_od_municipio: esperava 6 colunas, encontrei %', n;
  END IF;
END
$$;

ROLLBACK;
