-- Verify edumaps:cnpj_municipio on pg
--
-- DO/RAISE EXCEPTION (issue #160): o verify só falha quando o script
-- produz ERRO; um SELECT que devolve 0 linhas conta como sucesso.

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.cnpj_municipio') IS NULL THEN
    RAISE EXCEPTION 'cnpj_municipio: falta a tabela clean.cnpj_municipio';
  END IF;
END $$;

-- Colunas obrigatórias por pg_attribute (information_schema não cobre tudo).
DO $$
DECLARE
  faltam TEXT;
BEGIN
  SELECT string_agg(v.c, ', ' ORDER BY v.c) INTO faltam
  FROM (VALUES ('cnpj'), ('codigo_ibge'), ('uf'), ('municipio'), ('fonte'), ('atualizado_em')) AS v(c)
  WHERE NOT EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class cl ON cl.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    WHERE n.nspname = 'clean' AND cl.relname = 'cnpj_municipio'
      AND a.attname = v.c AND a.attnum > 0 AND NOT a.attisdropped
  );
  IF faltam IS NOT NULL THEN
    RAISE EXCEPTION 'cnpj_municipio: faltam colunas: %', faltam;
  END IF;
END $$;

-- PK em cnpj (é o que faz o ON CONFLICT do provedor funcionar).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class cl ON cl.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    WHERE n.nspname = 'clean' AND cl.relname = 'cnpj_municipio'
      AND c.contype = 'p'
      AND c.conkey = ARRAY[(
        SELECT a.attnum FROM pg_attribute a
        WHERE a.attrelid = cl.oid AND a.attname = 'cnpj')]::smallint[]
  ) THEN
    RAISE EXCEPTION 'cnpj_municipio: falta PRIMARY KEY em cnpj';
  END IF;
END $$;

ROLLBACK;
