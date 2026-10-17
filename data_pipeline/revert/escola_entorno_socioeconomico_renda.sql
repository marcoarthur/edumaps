-- Revert edumaps:escola_entorno_socioeconomico_renda from pg
--
-- Restaura a definição anterior de refresh_escola_entorno_socioeconomico()
-- (a de escola_entorno_socioeconomico_saneamento.sql, sem as colunas de renda
-- do responsável e com versao 'ivet-v1.1'), depois remove as colunas e repõe
-- o default da versão.

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
    RAISE EXCEPTION 'refresh_escola_entorno_socioeconomico: p_raios vazio';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(p_raios) r WHERE r IS NULL OR r <= 0) THEN
    RAISE EXCEPTION 'refresh_escola_entorno_socioeconomico: raio inválido (precisa > 0)';
  END IF;

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
      c.alf_nao_sabe_15mais,
      (c.alf_sabe_15mais + c.alf_nao_sabe_15mais)                 AS alf_total,
      (c.dom_esgoto_fossa_rudimentar + c.dom_esgoto_vala
       + c.dom_esgoto_rio + c.dom_esgoto_inexistente)             AS esgoto_inadequado,
      (c.dom_esgoto_rede + c.dom_esgoto_fossa_septica_rede
       + c.dom_esgoto_fossa_septica + c.dom_esgoto_fossa_rudimentar
       + c.dom_esgoto_vala + c.dom_esgoto_rio
       + c.dom_esgoto_outra + c.dom_esgoto_inexistente)           AS esgoto_total,
      c.dom_agua_rede,
      (c.dom_agua_rede + c.dom_agua_poco_profundo + c.dom_agua_poco_raso
       + c.dom_agua_nascente + c.dom_agua_carro_pipa + c.dom_agua_chuva
       + c.dom_agua_rio + c.dom_agua_outra)                       AS agua_total,
      (c.dom_lixo_queimado + c.dom_lixo_enterrado
       + c.dom_lixo_jogado + c.dom_lixo_outro)                    AS lixo_inadequado,
      (c.dom_lixo_coletado + c.dom_lixo_cacamba + c.dom_lixo_queimado
       + c.dom_lixo_enterrado + c.dom_lixo_jogado + c.dom_lixo_outro) AS lixo_total,
      c.dom_sem_banheiro,
      (c.dom_banheiro_exclusivo + c.dom_sem_banheiro)             AS banheiro_total,
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
        FILTER (WHERE pop_setor IS NOT NULL)               AS pop_est,
      sum(rend_per_capita * w)
        FILTER (WHERE rend_per_capita IS NOT NULL)
        / NULLIF(sum(w) FILTER (WHERE rend_per_capita IS NOT NULL), 0)
                                                           AS renda,
      sum((esc_sem_instrucao::numeric / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE esc_total > 0), 0)
                                                           AS pct_sem,
      sum((esc_fund_incomp::numeric / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE esc_total > 0), 0)
                                                           AS pct_fund,
      sum(((esc_med_comp + esc_sup_incomp + esc_sup_comp)::numeric
           / NULLIF(esc_total, 0)) * w)
        FILTER (WHERE esc_total > 0)
        / NULLIF(sum(w) FILTER (WHERE esc_total > 0), 0)
                                                           AS pct_medio_mais,
      sum((cor_pp::numeric / NULLIF(cor_total, 0)) * w)
        FILTER (WHERE cor_total > 0)
        / NULLIF(sum(w) FILTER (WHERE cor_total > 0), 0)
                                                           AS pct_pp,
      sum((alf_nao_sabe_15mais::numeric / NULLIF(alf_total, 0)) * w)
        FILTER (WHERE alf_total > 0)
        / NULLIF(sum(w) FILTER (WHERE alf_total > 0), 0)
                                                           AS pct_analfabeto,
      sum((esgoto_inadequado::numeric / NULLIF(esgoto_total, 0)) * w)
        FILTER (WHERE esgoto_total > 0)
        / NULLIF(sum(w) FILTER (WHERE esgoto_total > 0), 0)
                                                           AS pct_esgoto_inadequado,
      sum(((agua_total - dom_agua_rede)::numeric / NULLIF(agua_total, 0)) * w)
        FILTER (WHERE agua_total > 0)
        / NULLIF(sum(w) FILTER (WHERE agua_total > 0), 0)
                                                           AS pct_agua_sem_rede,
      sum((lixo_inadequado::numeric / NULLIF(lixo_total, 0)) * w)
        FILTER (WHERE lixo_total > 0)
        / NULLIF(sum(w) FILTER (WHERE lixo_total > 0), 0)
                                                           AS pct_lixo_inadequado,
      sum((dom_sem_banheiro::numeric / NULLIF(banheiro_total, 0)) * w)
        FILTER (WHERE banheiro_total > 0)
        / NULLIF(sum(w) FILTER (WHERE banheiro_total > 0), 0)
                                                           AS pct_sem_banheiro
    FROM base
    GROUP BY co_entidade, nu_ano_censo, raio_m
  )
  INSERT INTO clean.escola_entorno_socioeconomico
    (co_entidade, nu_ano_censo, raio_m,
     n_setores, n_setores_suprimidos, area_influencia_km2, area_coberta_km2, cobertura_pct,
     pop_total, densidade_pop_km2,
     renda_per_capita, pct_sem_instrucao, pct_fund_incomp, pct_medio_mais, pct_preto_pardo,
     pct_analfabeto, pct_esgoto_inadequado, pct_agua_sem_rede,
     pct_lixo_inadequado, pct_sem_banheiro,
     versao, computado_em)
  SELECT
    co_entidade, nu_ano_censo, raio_m,
    n_setores, n_suprimidos,
    round((area_inf / 1e6)::numeric, 4),
    round((area_com_dado / 1e6)::numeric, 4),
    round((COALESCE(area_com_dado, 0) / NULLIF(area_inf, 0))::numeric, 4),
    round(pop_est::numeric, 0),
    round((pop_est / NULLIF(area_inf / 1e6, 0))::numeric, 2),
    round(renda::numeric, 2),
    round(pct_sem::numeric, 4),
    round(pct_fund::numeric, 4),
    round(pct_medio_mais::numeric, 4),
    round(pct_pp::numeric, 4),
    round(pct_analfabeto::numeric, 4),
    round(pct_esgoto_inadequado::numeric, 4),
    round(pct_agua_sem_rede::numeric, 4),
    round(pct_lixo_inadequado::numeric, 4),
    round(pct_sem_banheiro::numeric, 4),
    'ivet-v1.1', now()
  FROM agg
  ON CONFLICT (co_entidade, nu_ano_censo, raio_m)
  DO UPDATE SET
    n_setores             = EXCLUDED.n_setores,
    n_setores_suprimidos  = EXCLUDED.n_setores_suprimidos,
    area_influencia_km2   = EXCLUDED.area_influencia_km2,
    area_coberta_km2      = EXCLUDED.area_coberta_km2,
    cobertura_pct         = EXCLUDED.cobertura_pct,
    pop_total             = EXCLUDED.pop_total,
    densidade_pop_km2     = EXCLUDED.densidade_pop_km2,
    renda_per_capita      = EXCLUDED.renda_per_capita,
    pct_sem_instrucao     = EXCLUDED.pct_sem_instrucao,
    pct_fund_incomp       = EXCLUDED.pct_fund_incomp,
    pct_medio_mais        = EXCLUDED.pct_medio_mais,
    pct_preto_pardo       = EXCLUDED.pct_preto_pardo,
    pct_analfabeto        = EXCLUDED.pct_analfabeto,
    pct_esgoto_inadequado = EXCLUDED.pct_esgoto_inadequado,
    pct_agua_sem_rede     = EXCLUDED.pct_agua_sem_rede,
    pct_lixo_inadequado   = EXCLUDED.pct_lixo_inadequado,
    pct_sem_banheiro      = EXCLUDED.pct_sem_banheiro,
    versao                = EXCLUDED.versao,
    computado_em          = EXCLUDED.computado_em;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

ALTER TABLE clean.escola_entorno_socioeconomico
  ALTER COLUMN versao SET DEFAULT 'ivet-v1.1';

ALTER TABLE clean.escola_entorno_socioeconomico
  DROP COLUMN IF EXISTS renda_resp_media,
  DROP COLUMN IF EXISTS renda_resp_mediana;

COMMIT;
