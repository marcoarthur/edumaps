-- Verify edumaps:gestores_senha_argon2id on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF col_description('clean.gestores'::regclass,
       (SELECT attnum FROM pg_attribute
         WHERE attrelid = 'clean.gestores'::regclass AND attname = 'senha_hash'))
     NOT LIKE 'Hash Argon2id%' THEN
    RAISE EXCEPTION 'comentário de clean.gestores.senha_hash não descreve o Argon2id';
  END IF;
END
$$;

ROLLBACK;
