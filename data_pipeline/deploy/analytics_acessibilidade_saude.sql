-- Deploy edumaps:analytics_acessibilidade_saude to pg
-- requires: cnes_estabelecimentos
-- requires: sisab_aps
-- requires: malha_municipio
-- requires: extensions

BEGIN;

-- =================================================================
-- VIEW ANALÍTICA: ACESSIBILIDADE SAÚDE
-- Cruza CNES (oferta em ponto) + Escola (demanda) + Malha/OSM
-- =================================================================

-- Tipos de unidade CNES que interessam (UBS, eSF, etc.)
-- Fonte: /cnes/tipounidades
-- 11 = Unidade Básica de Saúde (UBS)
-- 12 = Unidade de Saúde da Família (USF)
-- 13 = Unidade de Pronto Atendimento (UPA)
-- 72 = Serviço de Atendimento Móvel de Urgência (SAMU)
-- 73 = Hospital
-- 74 = Maternidade
-- etc. (ver /cnes/tipounidades)

DROP VIEW IF EXISTS analytics.acessibilidade_saude;
CREATE VIEW analytics.acessibilidade_saude AS
WITH
    -- Escolas ativas do Censo mais recente
    escolas AS (
        SELECT
            e.co_entidade,
            e.no_entidade,
            e.co_municipio AS codigo_ibge,
            e.latitude,
            e.longitude,
            e.tp_dependencia,
            ST_SetSRID(ST_MakePoint(e.longitude, e.latitude), 4674) AS geom
        FROM clean.censo_escolas e
        WHERE e.tp_situacao_funcionamento = 1
          AND e.latitude IS NOT NULL
          AND e.longitude IS NOT NULL
          AND e.nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_escolas)
    ),
    -- UBS/USF ativas do CNES (snapshot mais recente)
    ubs AS (
        SELECT
            c.codigo_cnes,
            c.codigo_municipio::text AS codigo_ibge,
            c.codigo_tipo_unidade,
            c.latitude,
            c.longitude,
            c.dt_snapshot,
            ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4674) AS geom
        FROM clean.cnes_estabelecimentos c
        WHERE c.status = 1
          AND c.codigo_tipo_unidade IN (11, 12)  -- UBS, USF
          AND c.latitude IS NOT NULL
          AND c.longitude IS NOT NULL
          AND c.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.cnes_estabelecimentos)
    ),
    -- Cobertura APS por município (snapshot mais recente)
    aps AS (
        SELECT
            s.codigo_municipio,
            s.cobertura_aps,
            s.ativas_ff,
            s.equipe_esf,
            s.equipe_emsi,
            s.total_vagas_ativas,
            s.ocupadas,
            s.categoria_ivs,
            s.dt_snapshot
        FROM clean.sisab_aps s
        WHERE s.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.sisab_aps)
    ),
    -- Distância haversine escola -> UBS mais próxima (em km)
    distancias AS (
        SELECT
            e.co_entidade,
            e.no_entidade,
            e.codigo_ibge,
            e.tp_dependencia,
            MIN(
                ST_Distance(e.geom, u.geom) / 1000.0  -- metros -> km (aprox)
            ) AS dist_min_km_ubs,
            COUNT(u.codigo_cnes) AS n_ubs_municipio
        FROM escolas e
        LEFT JOIN ubs u ON u.codigo_ibge = e.codigo_ibge::text
        GROUP BY e.co_entidade, e.no_entidade, e.codigo_ibge, e.tp_dependencia
    )
SELECT
    d.co_entidade,
    d.no_entidade,
    d.codigo_ibge,
    d.tp_dependencia,
    d.dist_min_km_ubs,
    d.n_ubs_municipio,
    a.cobertura_aps,
    a.ativas_ff,
    a.equipe_esf,
    a.equipe_emsi,
    a.categoria_ivs,
    -- Indicadores derivados
    CASE
        WHEN d.dist_min_km_ubs IS NOT NULL THEN
            CASE
                WHEN d.dist_min_km_ubs <= 1 THEN 'Acesso excelente (<1km)'
                WHEN d.dist_min_km_ubs <= 3 THEN 'Acesso bom (1-3km)'
                WHEN d.dist_min_km_ubs <= 5 THEN 'Acesso regular (3-5km)'
                ELSE 'Acesso difícil (>5km)'
            END
        ELSE 'Sem UBS no município'
    END AS classificacao_acesso,
    -- Efetividade APS
    CASE
        WHEN a.total_vagas_ativas > 0 THEN
            round(a.ocupadas::numeric / a.total_vagas_ativas * 100, 1)
        ELSE NULL
    END AS efetividade_vagas_aps,
    -- Metadados
    a.dt_snapshot AS aps_snapshot,
    ubs.dt_snapshot AS cnes_snapshot,
    CURRENT_DATE AS computed_at
FROM distancias d
LEFT JOIN aps a ON a.codigo_municipio = d.codigo_ibge::text
LEFT JOIN (
    SELECT codigo_municipio, MAX(dt_snapshot) AS dt_snapshot
    FROM clean.cnes_estabelecimentos
    WHERE codigo_tipo_unidade IN (11, 12) AND status = 1
    GROUP BY codigo_municipio
) ubs ON ubs.codigo_municipio = d.codigo_ibge::text;

-- Comentários da view
COMMENT ON VIEW analytics.acessibilidade_saude IS 'Acessibilidade da escola à rede de saúde (UBS/USF). Cruza CNES (oferta em ponto) + SISAB (efetividade APS) + Censo Escolar (demanda). Distância haversine aproximada; substituir por roteamento OSM quando malha viária estiver disponível.';

COMMIT;