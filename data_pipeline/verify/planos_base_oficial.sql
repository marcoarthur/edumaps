-- Verify edumaps:planos_base_oficial on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
                  WHERE attrelid = 'clean.planos_metas'::regclass
                    AND attname = 'linha_base_oficial' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'planos_base_oficial: falta clean.planos_metas.linha_base_oficial';
  END IF;
END
$$;

ROLLBACK;
