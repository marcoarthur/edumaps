-- Deploy edumaps:escola_entorno_socioeconomico to pg
-- requires: escola_influencia
-- requires: censo2022_setor
--
-- #137 (bloco B, entregável 3 — metade de extração): **arealização
-- socioeconômica do entorno da escola**.
--
-- Intersecta os setores do Censo 2022 (clean.malha_setor_censitario +
-- clean.censo2022_setor) com a área de influência da escola
-- (clean.escola_influencia, Tier 1 = buffer) e agrega com **peso = área de
-- interseção** — a arealização prescrita pela metodologia `influencia-v1`
-- (docs/analises/influencia.md §4, Tier 3). O setor é a *unidade do dado*; a
-- área de influência é a *geometria*.
--
--   componente_escola = Σ_setor ( valor_setor × área_interseção )
--                       / Σ_setor ( área_interseção )
--
-- Vazio ≠ zero (#154): setor com `supressao_celula_pequena = true` NÃO entra no
-- numerador nem no denominador — nunca é tratado como 0. A fração da área
-- efetivamente usada é exposta em `cobertura_pct`; sem nenhum setor com dado, os
-- componentes ficam NULL e `cobertura_pct = 0` (sem extração, não "zero de
-- vulnerabilidade").
--
-- Grão: (co_entidade, nu_ano_censo, raio_m) — um registro por escola/ano/raio
-- da camada de influência. Populada por
-- clean.refresh_escola_entorno_socioeconomico().

BEGIN;

CREATE TABLE clean.escola_entorno_socioeconomico (
  co_entidade         BIGINT      NOT NULL,
  nu_ano_censo        INTEGER     NOT NULL,
  raio_m              INTEGER     NOT NULL,
  n_setores           INTEGER     NOT NULL,
  n_setores_suprimidos INTEGER    NOT NULL DEFAULT 0,
  area_influencia_km2 NUMERIC,
  area_coberta_km2    NUMERIC,
  cobertura_pct       NUMERIC,
  pop_total           NUMERIC,
  renda_per_capita    NUMERIC,
  pct_sem_instrucao   NUMERIC,
  pct_fund_incomp     NUMERIC,
  pct_medio_mais      NUMERIC,
  pct_preto_pardo     NUMERIC,
  densidade_pop_km2   NUMERIC,
  versao              TEXT        NOT NULL DEFAULT 'ivet-v1.0',
  computado_em        TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pk_escola_entorno_socioeconomico
    PRIMARY KEY (co_entidade, nu_ano_censo, raio_m),
  CONSTRAINT escola_entorno_raio_ck CHECK (raio_m > 0)
);

COMMENT ON TABLE clean.escola_entorno_socioeconomico IS
'Arealização socioeconômica do entorno da escola (#137, bloco B): setores do Censo 2022 intersectados com a área de influência (clean.escola_influencia), peso = área de interseção (influencia-v1, docs/analises/influencia.md §4 Tier 3). Vazio ≠ zero (#154): setor suprimido não entra no cálculo; ver cobertura_pct. Populada por clean.refresh_escola_entorno_socioeconomico().';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.co_entidade IS 'Código INEP da escola (clean.censo_escolas.co_entidade).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.nu_ano_censo IS 'Ano do Censo Escolar da geometria de origem.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.raio_m IS 'Raio do buffer em metros (tier=buffer).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.n_setores IS 'Setores censitários que intersectam a área de influência.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.n_setores_suprimidos IS 'Setores intersectados com supressao_celula_pequena = true (fora do cálculo).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.area_influencia_km2 IS 'Área total do buffer (km², medida em geodésica).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.area_coberta_km2 IS 'Área da interseção com setores NÃO suprimidos (km²).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.cobertura_pct IS 'area_coberta / area_influencia em [0,1]. 0 = nenhum setor com dado (sem extração).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.pop_total IS 'População estimada no entorno (fração do setor dentro do buffer × pop_total, só setores com dado).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.renda_per_capita IS 'Rendimento médio per capita (R$/mês), média ponderada por área.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.pct_sem_instrucao IS 'Proporção de pessoas 25+ sem instrução (média ponderada por área).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.pct_fund_incomp IS 'Proporção de pessoas 25+ com fundamental incompleto.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.pct_medio_mais IS 'Proporção de pessoas 25+ com médio completo ou mais.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.pct_preto_pardo IS 'Proporção de pessoas pretas ou pardas (equidade).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.densidade_pop_km2 IS 'Densidade demográfica estimada no entorno (hab/km²).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.versao IS 'Versão da fórmula/metodologia que consome estes componentes (ivet-v1.0).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.computado_em IS 'Quando a arealização foi (re)calculada.';

CREATE INDEX ix_escola_entorno_socioeconomico_ano
  ON clean.escola_entorno_socioeconomico (nu_ano_censo, raio_m);

-- ---------------------------------------------------------------------------
-- refresh_escola_entorno_socioeconomico(): (re)materializa a arealização de
-- forma idempotente (UPSERT).
--
--   p_raios        raios em metros (default: os três da metodologia)
--   p_co_entidades filtro opcional por escola (testes / refresh incremental)
--
-- Devolve o número de linhas afetadas.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION clean.refresh_escola_entorno_socioeconomico(
  p_raios        integer[] DEFAULT ARRAY[500, 1000, 2000],
  p_co_entidades bigint[]  DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_n integer;
BEGIN
  IF p_raios IS NULL OR array_length(p_raios, 1) IS NULL THEN
    RAISE EXCEPTION 'p_raios não pode ser nulo/vazio';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(p_raios) r WHERE r <= 0) THEN
    RAISE EXCEPTION 'raio precisa ser > 0';
  END IF;

  INSERT INTO clean.escola_entorno_socioeconomico (
    co_entidade, nu_ano_censo, raio_m, n_setores, n_setores_suprimidos,
    area_influencia_km2, area_coberta_km2, cobertura_pct,
    pop_total, renda_per_capita, pct_sem_instrucao, pct_fund_incomp,
    pct_medio_mais, pct_preto_pardo, densidade_pop_km2, versao, computado_em
  )
  WITH base AS (
    SELECT
      i.co_entidade, i.nu_ano_censo, i.raio_m,
      ST_Area(i.geom::geography)                                  AS area_inf,
      ST_Area(ST_Intersection(i.geom, m.geometry)::geography)     AS w,
      ST_Area(m.geometry::geography)                              AS area_setor,
      c.pop_total                                                 AS pop_setor,
      c.rend_per_capita,
      c.esc_sem_instrucao, c.esc_fund_incomp,
      c.esc_med_comp, c.esc_sup_incomp, c.esc_sup_comp,
      (c.esc_sem_instrucao + c.esc_fund_incomp + c.esc_fund_comp
       + c.esc_med_incomp + c.esc_med_comp + c.esc_sup_incomp
       + c.esc_sup_comp)                                          AS esc_total,
      (c.cor_preta + c.cor_parda)                                 AS cor_pp,
      -- cor_sem_decl fica de fora: sem fonte no Censo 2022 por setor
      -- (decisão #238), sempre NULL — incluí-la anularia o denominador.
      (c.cor_branca + c.cor_preta + c.cor_amarela + c.cor_parda
       + c.cor_indigena)                                          AS cor_total,
      COALESCE(c.supressao_celula_pequena, false)                 AS supressao
    FROM clean.escola_influencia i
    JOIN clean.malha_setor_censitario m
      ON ST_Intersects(i.geom, m.geometry)
    JOIN clean.censo2022_setor c
      ON c.codigo_setor = m.codigo_setor
    WHERE i.tier = 'buffer'
      AND i.raio_m = ANY (p_raios)
      AND (p_co_entidades IS NULL OR i.co_entidade = ANY (p_co_entidades))
  ),
  agg AS (
    SELECT
      co_entidade, nu_ano_censo, raio_m,
      max(area_inf)                                        AS area_inf,
      count(*)                                             AS n_setores,
      count(*) FILTER (WHERE supressao)                    AS n_suprimidos,
      sum(w) FILTER (WHERE NOT supressao)                  AS area_com_dado,
      sum(pop_setor * w / NULLIF(area_setor, 0))
        FILTER (WHERE NOT supressao)                       AS pop_est,
      sum(rend_per_capita * w)
        FILTER (WHERE NOT supressao AND rend_per_capita IS NOT NULL)
        / NULLIF(sum(w) FILTER (WHERE NOT supressao AND rend_per_capita IS NOT NULL), 0)
                                                           AS renda,
      sum((esc_sem_instrucao::numeric / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE NOT supressao AND esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE NOT supressao AND esc_total > 0), 0)
                                                           AS pct_sem,
      sum((esc_fund_incomp::numeric / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE NOT supressao AND esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE NOT supressao AND esc_total > 0), 0)
                                                           AS pct_fund,
      sum(((esc_med_comp + esc_sup_incomp + esc_sup_comp)::numeric
           / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE NOT supressao AND esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE NOT supressao AND esc_total > 0), 0)
                                                           AS pct_medio_mais,
      sum((cor_pp::numeric / NULLIF(cor_total, 0)) * w)
        FILTER (WHERE NOT supressao AND cor_total > 0)
        / NULLIF(sum(w) FILTER (WHERE NOT supressao AND cor_total > 0), 0)
                                                           AS pct_pp
    FROM base
    GROUP BY co_entidade, nu_ano_censo, raio_m
  )
  SELECT
    co_entidade, nu_ano_censo, raio_m, n_setores, n_suprimidos,
    round((area_inf / 1e6)::numeric, 4),
    round((area_com_dado / 1e6)::numeric, 4),
    round((COALESCE(area_com_dado, 0) / NULLIF(area_inf, 0))::numeric, 4),
    round(pop_est::numeric, 0),
    round(renda::numeric, 2),
    round(pct_sem::numeric, 4),
    round(pct_fund::numeric, 4),
    round(pct_medio_mais::numeric, 4),
    round(pct_pp::numeric, 4),
    round((pop_est / NULLIF(area_inf / 1e6, 0))::numeric, 2),
    'ivet-v1.0', now()
  FROM agg
  ON CONFLICT (co_entidade, nu_ano_censo, raio_m)
  DO UPDATE SET
    n_setores            = EXCLUDED.n_setores,
    n_setores_suprimidos = EXCLUDED.n_setores_suprimidos,
    area_influencia_km2  = EXCLUDED.area_influencia_km2,
    area_coberta_km2     = EXCLUDED.area_coberta_km2,
    cobertura_pct        = EXCLUDED.cobertura_pct,
    pop_total            = EXCLUDED.pop_total,
    renda_per_capita     = EXCLUDED.renda_per_capita,
    pct_sem_instrucao    = EXCLUDED.pct_sem_instrucao,
    pct_fund_incomp      = EXCLUDED.pct_fund_incomp,
    pct_medio_mais       = EXCLUDED.pct_medio_mais,
    pct_preto_pardo      = EXCLUDED.pct_preto_pardo,
    densidade_pop_km2    = EXCLUDED.densidade_pop_km2,
    versao               = EXCLUDED.versao,
    computado_em         = EXCLUDED.computado_em;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

COMMENT ON FUNCTION clean.refresh_escola_entorno_socioeconomico(integer[], bigint[]) IS
'Arealiza os setores do Censo 2022 sobre a área de influência da escola (#137, bloco B), peso = área de interseção. Idempotente (UPSERT). Setor suprimido fica fora do cálculo (#154). Devolve as linhas afetadas.';

COMMIT;
