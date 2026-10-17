-- Deploy edumaps:analytics_acessibilidade_saude_ubs to pg
-- requires: analytics_views_materializadas
--
-- #137 bloco D — três defeitos medidos na fonte de saúde (2026-10-17):
--
-- 1. FILTRO CNES ERRADO. A view filtrava `codigo_tipo_unidade IN (11, 12)`,
--    mas o dicionário OFICIAL (/cnes/tipounidades) NÃO tem os códigos 11/12.
--    A atenção básica está no código 2 ("CENTRO DE SAUDE/UNIDADE BASICA") e
--    no 1 ("POSTO DE SAUDE"). Resultado medido: `dist_min_km_ubs` NULL em
--    145.734/145.734 escolas e `classificacao_acesso` = "Sem UBS no
--    município" em 100% delas. Corrigido para `IN (1, 2)` — 50.715
--    estabelecimentos ativos com coordenada, em 5.567/5.573 municípios.
--
-- 2. DISTÂNCIA EM GRAUS. `ST_Distance(geom, geom)` sobre geometria SRID 4674
--    devolve GRAUS, não metros; a `/ 1000.0` dava micro-quilómetros. Trocado
--    por `ST_DistanceSphere`, que devolve metros (distância esférica).
--
-- 3. ZERO REAL VIRAVA NULL. Sem UBS no município, o LEFT JOIN do pré-agregado
--    devolvia NULL, não 0 — o oposto do que a #154 pede (zero real ≠ fonte
--    vazia). O `COALESCE(..., 0)` no ramo em que o CNES tem dado é o que
--    separa os dois estados.
--
-- A view é materializada (#158): a fachada `analytics.acessibilidade_saude`
-- lê `analytics.mv_acessibilidade_saude`. A correção reconstrói a MV a partir
-- da definição corrigida — mesmo desenho de analytics_views_materializadas
-- (a lógica não é duplicada; a MV é repopulada na criação).

BEGIN;

-- 1. A fachada sai do caminho e a definição corrigida entra como VIEW.
DROP VIEW analytics.acessibilidade_saude;

CREATE VIEW analytics.acessibilidade_saude AS
WITH
    -- Contagem de registos por fonte: separa 'fonte vazia' de
    -- 'município sem oferta'. Sem isto, os dois casos viram 0.
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
    -- Atenção básica do CNES (snapshot mais recente). Códigos do dicionário
    -- OFICIAL (/cnes/tipounidades): 1 = Posto de Saúde,
    -- 2 = Centro de Saúde / Unidade Básica de Saúde (UBS).
    ubs AS (
        SELECT
            c.codigo_cnes,
            c.codigo_municipio::text AS codigo_ibge,
            c.latitude,
            c.longitude,
            ST_SetSRID(ST_MakePoint(c.longitude, c.latitude), 4674) AS geom
        FROM clean.cnes_estabelecimentos c
        WHERE c.status = 1
          AND c.codigo_tipo_unidade IN (1, 2)  -- Posto de Saúde, UBS
          AND c.latitude IS NOT NULL
          AND c.longitude IS NOT NULL
          AND c.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.cnes_estabelecimentos)
    ),
    -- PMMB por município (snapshot mais recente). ATENÇÃO: apesar do nome,
    -- `cobertura_aps` é a POPULAÇÃO coberta estimada pelo Programa Mais
    -- Médicos (pessoas), não a cobertura APS em % — ver o cabeçalho de
    -- EduMaps::Ingestion::Job::SISAB.
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
    -- Contagem de UBS por município (pré-agregado; uma linha por município,
    -- sem fan-out). Município sem UBS não entra aqui — o COALESCE no SELECT
    -- final distingue esse zero real da fonte vazia.
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
    -- Distância da escola à UBS mais próxima, em km. `ST_DistanceSphere`
    -- mede em METROS (esfera); `ST_Distance` sobre 4674 mediria GRAUS.
    distancias AS (
        SELECT
            e.co_entidade,
            MIN(ST_DistanceSphere(e.geom, u.geom) / 1000.0) AS dist_min_km_ubs
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
    -- Fonte CNES vazia => NULL (não avaliável), não 0.
    -- Fonte com dado e município sem UBS => 0 (zero real, #154).
    CASE WHEN f.n_cnes = 0 THEN NULL
         ELSE COALESCE(um.n_ubs_municipio, 0) END AS n_ubs_municipio,
    a.cobertura_aps,
    a.ativas_ff,
    a.equipe_esf,
    a.equipe_emsi,
    a.categoria_ivs,
    -- 'Sem UBS no município' só é verdade se o CNES tiver dado.
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
    -- Efetividade PMMB: NULL se a fonte está vazia ou se não há vaga ativa.
    CASE
        WHEN f.n_sisab = 0 THEN NULL
        WHEN a.total_vagas_ativas > 0 THEN
            round(a.ocupadas::numeric / a.total_vagas_ativas * 100, 1)
        ELSE NULL
    END AS efetividade_vagas_aps,
    -- Metadados
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
'Acessibilidade da escola à atenção básica de saúde (Posto/UBS do CNES, códigos 1 e 2 do dicionário oficial). OFERTA: dist_min_km_ubs = distância esférica (ST_DistanceSphere) da escola à UBS mais próxima, em km; n_ubs_municipio = contagem de UBS ativas no município. DEMANDA/EFETIVIDADE: cobertura_aps e efetividade_vagas_aps vêm do SISAB/PMMB (Programa Mais Médicos) — cobertura_aps é POPULAÇÃO coberta estimada (pessoas), NÃO cobertura APS em %. SEMÂNTICA DA AUSÊNCIA (#154): fonte CNES vazia => n_ubs_municipio e dist_min_km_ubs NULL e classificacao_acesso = ''Não avaliado (fonte CNES sem snapshot)''; fonte com dado e município sem UBS => n_ubs_municipio = 0 (zero real) e classificacao_acesso = ''Sem UBS no município''. Substituir a distância esférica por roteamento OSM quando a malha viária estiver disponível.';

-- Reconstroi a fachada materializada (#158) a partir da definição corrigida.
-- Mesmo desenho da change analytics_views_materializadas: a lógica não é
-- duplicada (pg_get_viewdef) e a MV é repopulada na criação.
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
