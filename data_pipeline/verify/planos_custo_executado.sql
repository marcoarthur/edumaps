-- Verify edumaps:planos_custo_executado on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM pg_attribute
       WHERE attrelid = 'clean.planos_acoes'::regclass AND NOT attisdropped
         AND attname IN ('custo_executado', 'executado_em')) <> 2 THEN
    RAISE EXCEPTION 'planos_custo_executado: faltam custo_executado/executado_em em clean.planos_acoes';
  END IF;
END
$$;

ROLLBACK;
