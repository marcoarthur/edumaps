-- Deploy edumaps:escola_entorno_socioeconomico_renda to pg
-- requires: escola_entorno_socioeconomico_saneamento
-- requires: censo2022_setor_renda_responsavel
--
-- #238/#137: fecha a renda do bloco B do IVET. A change anterior deu conteúdo
-- a instrução (alfabetização) e saneamento; a renda ficou de fora porque se
-- supunha não haver fonte por setor. Há (change censo2022_setor_renda_responsavel):
-- o produto Rendimento_do_Responsavel traz, por setor, o rendimento MÉDIO
-- (V06004) e MEDIANO (V06006) do responsável, com o nº de responsáveis (V06001).
--
-- Esta change:
--   1. acrescenta `renda_resp_media` e `renda_resp_mediana` à tabela arealizada;
--   2. redefine refresh_escola_entorno_socioeconomico() para preenchê-las;
--   3. sobe a fórmula carimbada em `versao` (ivet-v1.1 → ivet-v1.2): o conjunto
--      de componentes do bloco B passa a incluir a renda.
--
-- PESO da renda: como a renda é do RESPONSÁVEL (não da área nem da população
-- total), o peso é o nº estimado de responsáveis na interseção:
--   peso_setor = rend_resp_count * (w / area_setor)
--   renda_resp_media = Σ(rend_media * peso_setor) / Σ(peso_setor)
-- A mediana arealizada é a média ponderada das medianas dos setores — uma
-- aproximação (não se reconstrói a mediana real sem a distribuição).
--
-- Ausência (#154) por CÉLULA, como os demais: o setor sai do numerador E do
-- denominador se rend_media/rend_mediana for NULL ou se não houver responsáveis.

BEGIN;

ALTER TABLE clean.escola_entorno_socioeconomico
  ADD COLUMN IF NOT EXISTS renda_resp_media   NUMERIC,
  ADD COLUMN IF NOT EXISTS renda_resp_mediana NUMERIC;

ALTER TABLE clean.escola_entorno_socioeconomico
  ALTER COLUMN versao SET DEFAULT 'ivet-v1.2';

COMMENT ON COLUMN clean.escola_entorno_socioeconomico.renda_resp_media IS
  'Rendimento nominal médio mensal do responsável (R$/mês), média ponderada pelos responsáveis estimados na interseção (rend_resp_count × w/area_setor).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.renda_resp_mediana IS
  'Média ponderada (responsáveis) das MEDIANAS setoriais do rendimento do responsável (R$). Aproximação da mediana arealizada.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.versao IS
  'Versão da fórmula/metodologia que consome estes componentes (ivet-v1.2).';

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
      c.rend_media, c.rend_mediana, c.rend_resp_count,
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
      -- alfabetização 15+
      c.alf_nao_sabe_15mais,
      (c.alf_sabe_15mais + c.alf_nao_sabe_15mais)                 AS alf_total,
      -- esgoto: inadequado = rudimentar + vala + rio/lago + inexistente;
      -- "outra forma" fica no denominador, não no numerador.
      (c.dom_esgoto_fossa_rudimentar + c.dom_esgoto_vala
       + c.dom_esgoto_rio + c.dom_esgoto_inexistente)             AS esgoto_inadequado,
      (c.dom_esgoto_rede + c.dom_esgoto_fossa_septica_rede
       + c.dom_esgoto_fossa_septica + c.dom_esgoto_fossa_rudimentar
       + c.dom_esgoto_vala + c.dom_esgoto_rio
       + c.dom_esgoto_outra + c.dom_esgoto_inexistente)           AS esgoto_total,
      -- água: sem rede = total − rede geral
      c.dom_agua_rede,
      (c.dom_agua_rede + c.dom_agua_poco_profundo + c.dom_agua_poco_raso
       + c.dom_agua_nascente + c.dom_agua_carro_pipa + c.dom_agua_chuva
       + c.dom_agua_rio + c.dom_agua_outra)                       AS agua_total,
      -- lixo: inadequado = queimado + enterrado + jogado + outro
      (c.dom_lixo_queimado + c.dom_lixo_enterrado
       + c.dom_lixo_jogado + c.dom_lixo_outro)                    AS lixo_inadequado,
      (c.dom_lixo_coletado + c.dom_lixo_cacamba + c.dom_lixo_queimado
       + c.dom_lixo_enterrado + c.dom_lixo_jogado + c.dom_lixo_outro) AS lixo_total,
      -- banheiro: sem banheiro de uso exclusivo
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
      -- Ausência é por CÉLULA (#154): cada componente usa `> 0`/`IS NOT NULL`
      -- do seu próprio insumo, e o setor sai do numerador e do denominador
      -- daquele indicador se a variável-fonte está NULL (célula suprimida).
      --
      -- NÃO se usa `supressao` (flag do setor) como gate: é o OR de dezenas
      -- de variáveis e, com as do bloco B, marca ~88% dos setores — mutilaria
      -- a base de TODOS os indicadores (~12% da área). O flag segue em
      -- `n_setores_suprimidos`/`area_com_dado` como proveniência.
      sum(pop_setor * w / NULLIF(area_setor, 0))
        FILTER (WHERE pop_setor IS NOT NULL)               AS pop_est,
      sum(rend_per_capita * w)
        FILTER (WHERE rend_per_capita IS NOT NULL)
        / NULLIF(sum(w) FILTER (WHERE rend_per_capita IS NOT NULL), 0)
                                                           AS renda,
      -- Renda do responsável: peso = responsáveis estimados na interseção
      -- (nº de responsáveis, não área nem população total).
      sum(rend_media * rend_resp_count * w / NULLIF(area_setor, 0))
        FILTER (WHERE rend_media IS NOT NULL AND rend_resp_count > 0)
        / NULLIF(sum(rend_resp_count * w / NULLIF(area_setor, 0))
                 FILTER (WHERE rend_media IS NOT NULL AND rend_resp_count > 0), 0)
                                                           AS renda_resp_media,
      sum(rend_mediana * rend_resp_count * w / NULLIF(area_setor, 0))
        FILTER (WHERE rend_mediana IS NOT NULL AND rend_resp_count > 0)
        / NULLIF(sum(rend_resp_count * w / NULLIF(area_setor, 0))
                 FILTER (WHERE rend_mediana IS NOT NULL AND rend_resp_count > 0), 0)
                                                           AS renda_resp_mediana,
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
     renda_resp_media, renda_resp_mediana,
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
    round(renda_resp_media::numeric, 2),
    round(renda_resp_mediana::numeric, 2),
    round(pct_analfabeto::numeric, 4),
    round(pct_esgoto_inadequado::numeric, 4),
    round(pct_agua_sem_rede::numeric, 4),
    round(pct_lixo_inadequado::numeric, 4),
    round(pct_sem_banheiro::numeric, 4),
    'ivet-v1.2', now()
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
    renda_resp_media      = EXCLUDED.renda_resp_media,
    renda_resp_mediana    = EXCLUDED.renda_resp_mediana,
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

COMMENT ON COLUMN clean.escola_entorno_socioeconomico.renda_resp_media IS
  'Rendimento nominal médio mensal do responsável (R$), arealizado com peso = nº estimado de responsáveis na interseção (rend_resp_count × w/area_setor).';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.renda_resp_mediana IS
  'Média ponderada das medianas setoriais do rendimento do responsável (R$) — aproximação da mediana arealizada. Mesmo peso da média.';
COMMENT ON COLUMN clean.escola_entorno_socioeconomico.versao IS
  'Versão da fórmula/metodologia que consome estes componentes (ivet-v1.2).';

COMMENT ON FUNCTION clean.refresh_escola_entorno_socioeconomico(integer[], bigint[]) IS
'Arealiza os setores do Censo 2022 sobre a área de influência da escola (#137, bloco B). Instrução/saneamento: peso = área de interseção. Renda do responsável: peso = nº estimado de responsáveis na interseção. Idempotente (UPSERT). Ausência por célula (#154): cada componente exclui do numerador e do denominador os setores sem a sua variável-fonte. Devolve as linhas afetadas.';

COMMIT;
