-- Verify edumaps:auth_falhas_canais on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF pg_get_constraintdef((SELECT oid FROM pg_constraint
        WHERE conname = 'auth_falhas_escopo_check')) NOT LIKE '%canais%' THEN
    RAISE EXCEPTION 'auth_falhas não aceita o escopo canais';
  END IF;
END
$$;

ROLLBACK;
