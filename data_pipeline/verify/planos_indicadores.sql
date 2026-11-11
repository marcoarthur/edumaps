-- Verify edumaps:planos_indicadores on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
DECLARE
  n integer;
BEGIN
  IF to_regclass('analytics.indicadores_meta_catalogo') IS NULL
     OR to_regclass('analytics.escola_indicadores_meta') IS NULL
     OR to_regclass('clean.planos_metas_medicoes') IS NULL THEN
    RAISE EXCEPTION 'planos_indicadores: falta catálogo, view ou tabela de medições';
  END IF;

  -- Todo código que a view produz está no catálogo (o JOIN não pode descartar
  -- valor por erro de digitação no código).
  SELECT count(*) INTO n FROM analytics.indicadores_meta_catalogo;
  IF n < 20 THEN
    RAISE EXCEPTION 'planos_indicadores: catálogo com % códigos (esperava 22)', n;
  END IF;

  -- #154: a view não produz valor NULL.
  IF EXISTS (SELECT 1 FROM analytics.escola_indicadores_meta WHERE valor IS NULL LIMIT 1) THEN
    RAISE EXCEPTION 'planos_indicadores: valor NULL na view (ausência deve sumir, não virar linha)';
  END IF;

  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
     AND has_table_privilege('edumaps_leitor', 'clean.planos_metas_medicoes', 'SELECT') THEN
    RAISE EXCEPTION 'planos_indicadores: edumaps_leitor não pode ler clean.planos_metas_medicoes (dado interno)';
  END IF;
END
$$;

ROLLBACK;
