-- Revert edumaps:escola_entorno_socioeconomico_saneamento from pg
--
-- Restaura a definição anterior de refresh_escola_entorno_socioeconomico()
-- (a de escola_entorno_socioeconomico.sql, sem as cinco proporções e com
-- versao 'ivet-v1.0'), depois remove as colunas e repõe o default.

BEGIN;

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

ALTER TABLE clean.escola_entorno_socioeconomico
  DROP COLUMN IF EXISTS pct_analfabeto,
  DROP COLUMN IF EXISTS pct_esgoto_inadequado,
  DROP COLUMN IF EXISTS pct_agua_sem_rede,
  DROP COLUMN IF EXISTS pct_lixo_inadequado,
  DROP COLUMN IF EXISTS pct_sem_banheiro;

ALTER TABLE clean.escola_entorno_socioeconomico
  ALTER COLUMN versao SET DEFAULT 'ivet-v1.0';

COMMENT ON COLUMN clean.escola_entorno_socioeconomico.versao IS
  'Versão da fórmula/metodologia que consome estes componentes (ivet-v1.0).';

COMMIT;
