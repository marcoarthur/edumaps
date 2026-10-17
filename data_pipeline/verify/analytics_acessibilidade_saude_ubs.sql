-- Verify edumaps:analytics_acessibilidade_saude_ubs on pg
--
-- O `sqitch verify` só falha quando o script ERRA (Sqitch 1.6.1) — por isso
-- cada asserção é um bloco DO com RAISE EXCEPTION (ver os verifies irmãos).

BEGIN;

DO $$
DECLARE
  n   INT;
  def TEXT;
BEGIN
  -- 1) A view pública continua VIEW (fachada #158) com as 16 colunas do contrato.
  SELECT COUNT(*) INTO n
  FROM information_schema.columns
  WHERE table_schema = 'analytics'
    AND table_name = 'acessibilidade_saude'
    AND column_name IN (
      'co_entidade', 'no_entidade', 'codigo_ibge', 'tp_dependencia',
      'dist_min_km_ubs', 'n_ubs_municipio', 'cobertura_aps', 'ativas_ff',
      'equipe_esf', 'equipe_emsi', 'categoria_ivs', 'classificacao_acesso',
      'efetividade_vagas_aps', 'aps_snapshot', 'cnes_snapshot', 'computed_at');
  IF n <> 16 THEN
    RAISE EXCEPTION
      'Contrato: analytics.acessibilidade_saude expõe % das 16 colunas esperadas.', n;
  END IF;

  -- 2) A MV existe e tem o índice único exigido por REFRESH ... CONCURRENTLY.
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews
    WHERE schemaname = 'analytics' AND matviewname = 'mv_acessibilidade_saude'
  ) THEN
    RAISE EXCEPTION 'Facade #158: analytics.mv_acessibilidade_saude não existe.';
  END IF;

  SELECT COUNT(*) INTO n
  FROM pg_index i
  JOIN pg_class c      ON c.oid = i.indrelid
  JOIN pg_namespace ns ON ns.oid = c.relnamespace
  WHERE ns.nspname = 'analytics'
    AND c.relname = 'mv_acessibilidade_saude'
    AND i.indisunique;
  IF n = 0 THEN
    RAISE EXCEPTION
      'Facade #158: mv_acessibilidade_saude sem índice único (REFRESH CONCURRENTLY falharia).';
  END IF;

  -- 3) DEFINIÇÃO: a distância é esférica (metros), não planar (graus).
  def := pg_get_viewdef('analytics.mv_acessibilidade_saude'::regclass, true);
  IF def !~* 'distancesphere' THEN
    RAISE EXCEPTION
      'Regressão: a MV de acessibilidade_saude não usa ST_DistanceSphere (distância sairia em graus?).';
  END IF;
  -- '\M' fecha a palavra: não confunde ST_Distance com ST_DistanceSphere.
  IF def ~* 'st_distance\M' THEN
    RAISE EXCEPTION
      'Regressão: a MV de acessibilidade_saude ainda usa ST_Distance planar (mediria graus, não metros).';
  END IF;

  -- 4) DADO REAL (só morde com o CNES carregado; vazio no banco de CI).
  IF EXISTS (
    SELECT 1 FROM clean.cnes_estabelecimentos
    WHERE status = 1
      AND codigo_tipo_unidade IN (1, 2)   -- Posto de Saúde, UBS
      AND latitude IS NOT NULL
  ) THEN
    -- Filtro de tipo tem de casar: alguma escola com distância calculada.
    SELECT COUNT(*) INTO n
    FROM analytics.acessibilidade_saude
    WHERE dist_min_km_ubs IS NOT NULL;
    IF n = 0 THEN
      RAISE EXCEPTION
        'Regressão: o CNES tem UBS (tipos 1/2), mas nenhuma escola recebeu dist_min_km_ubs — filtro de tipo ainda errado.';
    END IF;

    -- #154: com a fonte carregada, município sem UBS é 0 (zero real), não NULL.
    SELECT COUNT(*) INTO n
    FROM analytics.acessibilidade_saude
    WHERE n_ubs_municipio IS NULL;
    IF n > 0 THEN
      RAISE EXCEPTION
        'Contrato invertido (#154): % escola(s) com n_ubs_municipio NULL apesar de o CNES estar carregado.', n;
    END IF;
  END IF;
END $$;

ROLLBACK;
