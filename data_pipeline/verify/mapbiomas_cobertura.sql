-- Verify edumaps:mapbiomas_cobertura on pg
--
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION, issue #160): um SELECT
-- preguiçoso devolve 0 linhas e o Sqitch 1.6.1 reporta 'ok'.
--
-- Só a ESTRUTURA é verificada. Os DADOS vêm do job MapBiomas (#241), não desta
-- migration: num banco recém-deployado a tabela é legitimamente VAZIA, logo um
-- verify que exigisse linhas derrubaria o gate de CI. A verificação anterior era
-- o anti-padrão da #160 e ainda checava `collection9` e classes '3.1'/'3.2'
-- (esquema que nunca vigorou — a carga real é a Coleção 10 com classe numérica).

BEGIN;

DO $$
DECLARE
  faltando text;
BEGIN
  IF to_regclass('clean.mapbiomas_cobertura') IS NULL THEN
    RAISE EXCEPTION 'mapbiomas_cobertura: tabela clean.mapbiomas_cobertura não existe';
  END IF;

  -- Colunas e nulabilidade esperadas (area_ha/area_km2 são anuláveis no DDL).
  SELECT string_agg(c.c || ' (' || c.n || ')', ', ' ORDER BY c.c) INTO faltando
  FROM (VALUES
    ('codigo_ibge', 'NO'), ('ano', 'NO'), ('colecao', 'NO'), ('classe', 'NO'),
    ('classe_desc', 'YES'), ('area_ha', 'YES'), ('area_km2', 'YES')
  ) AS c(c, n)
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'mapbiomas_cobertura'
      AND column_name = c.c AND is_nullable = c.n);
  IF faltando IS NOT NULL THEN
    RAISE EXCEPTION 'mapbiomas_cobertura: colunas ausentes/nulabilidade errada: %', faltando;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'clean.mapbiomas_cobertura'::regclass
      AND contype = 'p' AND conname = 'pk_mapbiomas_cobertura') THEN
    RAISE EXCEPTION 'mapbiomas_cobertura: PK pk_mapbiomas_cobertura ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'clean.mapbiomas_cobertura'::regclass
      AND contype = 'f' AND conname = 'fk_mapbiomas_municipio'
      AND confrelid = 'clean.malha_municipio'::regclass) THEN
    RAISE EXCEPTION 'mapbiomas_cobertura: FK fk_mapbiomas_municipio -> clean.malha_municipio ausente';
  END IF;
END $$;

ROLLBACK;
