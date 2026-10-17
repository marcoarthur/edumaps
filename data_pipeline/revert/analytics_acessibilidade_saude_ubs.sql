-- Revert edumaps:analytics_acessibilidade_saude_ubs from pg
-- Restaura a definição anterior da view (change analytics_ausencia_visivel:
-- filtro CNES `IN (11, 12)` e distância planar) e reconstrói a MV/fachada.

BEGIN;

DROP VIEW analytics.acessibilidade_saude;

CREATE VIEW analytics.acessibilidade_saude AS
WITH
    fontes AS (
        SELECT
            (SELECT COUNT(*) FROM clean.cnes_estabelecimentos) AS n_cnes,
            (SELECT COUNT(*) FROM clean.sisab_aps)             AS n_sisab
    ),
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
    ubs AS (
        SELECT
            c.codigo_cnes,
            c.codigo_municipio::text AS codigo_ibge,
            c.latitude,
            c.longitude,
            ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4674) AS geom
        FROM clean.cnes_estabelecimentos c
        WHERE c.status = 1
          AND c.codigo_tipo_unidade IN (11, 12)  -- UBS, USF (códigos inexistentes)
          AND c.latitude IS NOT NULL
          AND c.longitude IS NOT NULL
          AND c.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.cnes_estabelecimentos)
    ),
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
    ubs_municipio AS (
        SELECT
            m.codigo_ibge,
            u.n_ubs_municipio
        FROM clean.malha_municipio m
        CROSS JOIN fontes f
        LEFT JOIN (
            SELECT
                codigo_ibge,
                COUNT(*) AS n_ubs_municipio
            FROM ubs
            GROUP BY codigo_ibge
        ) u ON u.codigo_ibge = m.codigo_ibge
    ),
    distancias AS (
        SELECT
            e.co_entidade,
            MIN(ST_Distance(e.geom, u.geom) / 1000.0) AS dist_min_km_ubs
        FROM escolas e
        JOIN ubs u ON u.codigo_ibge = e.codigo_ibge::text
        GROUP BY e.co_entidade
    )
SELECT
    e.co_entidade,
    e.no_entidade,
    e.codigo_ibge,
    e.tp_dependencia,
    d.dist_min_km_ubs,
    CASE WHEN f.n_cnes = 0 THEN NULL ELSE um.n_ubs_municipio END AS n_ubs_municipio,
    a.cobertura_aps,
    a.ativas_ff,
    a.equipe_esf,
    a.equipe_emsi,
    a.categoria_ivs,
    CASE
        WHEN f.n_cnes = 0 THEN 'Não avaliado (fonte CNES sem snapshot)'
        WHEN d.dist_min_km_ubs IS NOT NULL THEN
            CASE
                WHEN d.dist_min_km_ubs <= 1 THEN 'Acesso excelente (<1km)'
                WHEN d.dist_min_km_ubs <= 3 THEN 'Acesso bom (1-3km)'
                WHEN d.dist_min_km_ubs <= 5 THEN 'Acesso regular (3-5km)'
                ELSE 'Acesso difícil (>5km)'
            END
        ELSE 'Sem UBS no município'
    END AS classificacao_acesso,
    CASE
        WHEN f.n_sisab = 0 THEN NULL
        WHEN a.total_vagas_ativas > 0 THEN
            round(a.ocupadas::numeric / a.total_vagas_ativas * 100, 1)
        ELSE NULL
    END AS efetividade_vagas_aps,
    a.dt_snapshot AS aps_snapshot,
    CASE WHEN f.n_cnes = 0 THEN NULL
         ELSE (SELECT MAX(dt_snapshot) FROM clean.cnes_estabelecimentos)
    END AS cnes_snapshot,
    CURRENT_DATE AS computed_at
FROM escolas e
CROSS JOIN fontes f
LEFT JOIN aps a  ON a.codigo_municipio = e.codigo_ibge::text
LEFT JOIN ubs_municipio um ON um.codigo_ibge = e.codigo_ibge::text
LEFT JOIN distancias d     ON d.co_entidade = e.co_entidade;

COMMENT ON VIEW analytics.acessibilidade_saude IS
'Acessibilidade da escola à rede de saúde (UBS/USF). Cruza CNES (oferta em ponto) + SISAB (efetividade APS) + Censo Escolar (demanda). Distância haversine aproximada; substituir por roteamento OSM quando malha viária estiver disponível. SEMÂNTICA DA AUSÊNCIA: se a fonte CNES não tem snapshot, n_ubs_municipio e dist_min_km_ubs saem NULL e classificacao_acesso = ''Não avaliado (fonte CNES sem snapshot)''. O valor ''Sem UBS no município'' só aparece quando o CNES tem dado. Zero real (0 UBS) é distinto de fonte vazia (NULL).';

DROP MATERIALIZED VIEW analytics.mv_acessibilidade_saude;

DO $$
BEGIN
  EXECUTE format(
    'CREATE MATERIALIZED VIEW analytics.mv_acessibilidade_saude AS %s',
    pg_get_viewdef('analytics.acessibilidade_saude'::regclass, true));
END $$;

CREATE UNIQUE INDEX mv_acessibilidade_saude_pk
    ON analytics.mv_acessibilidade_saude (co_entidade);

CREATE OR REPLACE VIEW analytics.acessibilidade_saude AS
    SELECT * FROM analytics.mv_acessibilidade_saude;

COMMENT ON MATERIALIZED VIEW analytics.mv_acessibilidade_saude IS
'Materialização de analytics.acessibilidade_saude (#158): mesma definição, chave co_entidade. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real.';

COMMIT;
