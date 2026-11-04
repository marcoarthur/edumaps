-- Verify edumaps:sessoes_token_hash on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute
                  WHERE attrelid = 'clean.sessoes'::regclass AND attname = 'token_hash'
                    AND NOT attisdropped) THEN
    RAISE EXCEPTION 'clean.sessoes sem a coluna token_hash';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_attribute
              WHERE attrelid = 'clean.sessoes'::regclass AND attname = 'token'
                AND NOT attisdropped) THEN
    RAISE EXCEPTION 'clean.sessoes ainda tem a coluna token (em claro)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'sessoes_token_hash_formato') THEN
    RAISE EXCEPTION 'falta o CHECK de formato do token_hash';
  END IF;
END
$$;

ROLLBACK;
