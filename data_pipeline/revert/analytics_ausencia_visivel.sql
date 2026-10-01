-- Revert edumaps:analytics_ausencia_visivel from pg

-- Restaura as definições anteriores de analytics.acessibilidade_saude e
-- analytics.mobilidade_escola, incluindo o defeito #154 (COALESCE(..., 0)
-- e COUNT sobre fonte vazia publicado como 0).
--
-- ESTE REVERT REINTRODUZ O COMPORTAMENTO ERRADO DE PROPÓSITO. Ele existe
-- para desfazer a change, não para ser usado. Se algo depender da
-- semântica antiga (status_* sem 'fonte_vazia', por exemplo), o correto é
-- adaptar o consumidor, não reverter.
--
-- Nenhuma das duas views tem dependentes (verificado), por isso DROP é
-- seguro.

BEGIN;

-- -----------------------------------------------------------------
-- analytics.acessibilidade_saude (definição anterior)
-- -----------------------------------------------------------------
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

-- -----------------------------------------------------------------
-- analytics.mobilidade_escola (definição anterior)
-- -----------------------------------------------------------------
-- =================================================================
-- VIEW ANALÍTICA: MOBILIDADE ESCOLAR
-- Consolida todas as fontes de mobilidade em uma view única por escola
-- =================================================================

CREATE OR REPLACE VIEW analytics.mobilidade_escola AS
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
            e.tp_localizacao,
            ST_SetSRID(ST_MakePoint(e.longitude, e.latitude), 4674) AS geom
        FROM clean.censo_escolas e
        WHERE e.tp_situacao_funcionamento = 1
          AND e.latitude IS NOT NULL
          AND e.longitude IS NOT NULL
          AND e.nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_escolas)
    ),
    -- Isocronas OSRM/Valhalla (grade 1km, não por escola isolada)
    isocronas_raw AS (
        SELECT
            i.co_entidade,
            i.tempo_minutos,
            i.grid_id,
            i.populacao_grade,
            i.tileset_origin,
            i.tileset_build_date,
            i.engine,
            i.engine_version,
            i.dt_snapshot
        FROM clean.isocrona_escolar i
        WHERE i.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.isocrona_escolar)
    ),
    -- Isocronas agregadas por escola e tempo
    isocronas_agg AS (
        SELECT
            co_entidade,
            tempo_minutos,
            COUNT(DISTINCT grid_id) AS grid_count,
            COALESCE(SUM(populacao_grade), 0) AS populacao_total
        FROM isocronas_raw
        GROUP BY co_entidade, tempo_minutos
    ),
    -- Isocronas JSON por escola
    isocronas_json AS (
        SELECT
            co_entidade,
            jsonb_object_agg(
                tempo_minutos::text,
                jsonb_build_object('grid_count', grid_count, 'populacao_total', populacao_total)
            ) AS isocronas_por_tempo
        FROM isocronas_agg
        GROUP BY co_entidade
    ),
    -- ANTT MONITRIIP - Matriz OD município×município (últimos snapshot)
    antt_od AS (
        SELECT
            o.codigo_ibge_origem,
            o.codigo_ibge_destino,
            o.mes_viagem,
            o.quantidade_bilhetes,
            o.supressao_aplicada,
            o.dt_snapshot
        FROM clean.antt_od_municipio o
        WHERE o.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.antt_od_municipio)
          AND o.supressao_aplicada = FALSE
    ),
    -- RENAVAM frota agregada por município (último snapshot)
    renavam AS (
        SELECT
            r.codigo_ibge,
            r.ano,
            r.mes,
            r.total_frota,
            r.automoveis,
            r.moto,
            r.onibus,
            r.dt_snapshot
        FROM clean.renavam_frota_municipio r
        WHERE r.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.renavam_frota_municipio)
    ),
    -- ANTT acidentes por trecho + JOIN com trecho geodados para município
    antt_acidentes AS (
        SELECT
            a.id_acidente,
            a.concessionaria,
            a.data_acidente,
            a.km,
            a.trecho,
            t.codigo_ibge,
            t.municipio,
            t.geometry AS trecho_geom,
            a.tipo_acidente,
            a.classificacao,
            a.mortos,
            a.feridos_graves,
            a.feridos_leves,
            a.ilesos,
            a.dt_carga
        FROM clean.antt_acidente_trecho a
        JOIN clean.antt_trecho_geodados t ON t.trecho = a.trecho
        WHERE a.dt_carga = (SELECT MAX(dt_carga) FROM clean.antt_acidente_trecho)
    ),
    -- RENAEST sinistros + de-para localidade → município
    renaest AS (
        SELECT
            s.id_sinistro,
            s.localidade,
            s.uf,
            s.data_sinistro,
            s.tipo_sinistro,
            s.classificacao,
            s.mortos,
            s.feridos_graves,
            s.feridos_leves,
            s.ilesos,
            s.codigo_ibge,
            s.dt_snapshot
        FROM clean.renaest_sinistro s
        WHERE s.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.renaest_sinistro)
          AND s.codigo_ibge IS NOT NULL
    ),
    -- SNV/VMDA trechos com VMDA
    snv_vmda AS (
        SELECT
            v.concessionaria,
            v.trecho,
            v.codigo_ibge,
            v.vmda_total,
            v.vmda_leve,
            v.vmda_pesado,
            v.geometry AS trecho_geom,
            v.ano_referencia_modelo,
            v.fonte_modelagem
        FROM clean.snv_trecho_vmda v
        WHERE v.vmda_total IS NOT NULL
    ),
    -- Recife transporte escolar (único município com granularidade escolar)
    recife_transporte AS (
        SELECT
            r.co_entidade,
            r.ano,
            r.vagas_transporte,
            r.turno,
            r.dt_snapshot
        FROM clean.recife_transporte_escolar r
        WHERE r.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.recife_transporte_escolar)
    ),
    -- Municípios (para joins)
    municipios AS (
        SELECT
            m.codigo_ibge,
            m.nome_municipio,
            m.sigla_uf,
            m.geometry
        FROM clean.malha_municipio m
    ),
    -- Métricas por escola
    escola_metricas AS (
        SELECT
            e.co_entidade,
            e.no_entidade,
            e.codigo_ibge,
            e.tp_dependencia,
            e.tp_localizacao,
            e.latitude,
            e.longitude,
            e.geom,
            m.nome_municipio AS municipio_escola,
            m.sigla_uf AS uf_escola,
            -- Isocronas (agregadas por tempo)
            i.isocronas_por_tempo,
            -- ANTT OD (conexões do município da escola)
            jsonb_agg(
                jsonb_build_object(
                    'destino_ibge', o.codigo_ibge_destino,
                    'bilhetes', o.quantidade_bilhetes,
                    'mes', to_char(o.mes_viagem, 'YYYY-MM')
                )
            ) FILTER (WHERE o.codigo_ibge_origem = e.codigo_ibge::text) AS antt_od_saida,
            jsonb_agg(
                jsonb_build_object(
                    'origem_ibge', o.codigo_ibge_origem,
                    'bilhetes', o.quantidade_bilhetes,
                    'mes', to_char(o.mes_viagem, 'YYYY-MM')
                )
            ) FILTER (WHERE o.codigo_ibge_destino = e.codigo_ibge::text) AS antt_od_entrada,
            -- RENAVAM frota do município
            rnv.total_frota AS renavam_total_frota,
            rnv.automoveis AS renavam_automoveis,
            rnv.moto AS renavam_moto,
            rnv.onibus AS renavam_onibus,
            -- SNV/VMDA no município (aggregado)
            COALESCE(SUM(v.vmda_total), 0) AS vmda_total_municipio,
            COALESCE(SUM(v.vmda_leve), 0) AS vmda_leve_municipio,
            COALESCE(SUM(v.vmda_pesado), 0) AS vmda_pesado_municipio,
            -- ANTT acidentes no município (últimos 12 meses)
            COUNT(a.id_acidente) FILTER (WHERE a.data_acidente >= CURRENT_DATE - INTERVAL '12 months') AS acidentes_12m,
            COUNT(a.id_acidente) FILTER (WHERE a.classificacao ILIKE '%fatal%' AND a.data_acidente >= CURRENT_DATE - INTERVAL '12 months') AS acidentes_fatais_12m,
            -- RENAEST sinistros no município (últimos 12 meses)
            COUNT(re.id_sinistro) FILTER (WHERE re.data_sinistro >= CURRENT_DATE - INTERVAL '12 months') AS sinistros_12m,
            COUNT(re.id_sinistro) FILTER (WHERE re.classificacao ILIKE '%fatal%' AND re.data_sinistro >= CURRENT_DATE - INTERVAL '12 months') AS sinistros_fatais_12m,
            -- Recife transporte escolar (se escola em Recife)
            rt.vagas_transporte AS recife_vagas_transporte,
            rt.turno AS recife_turno
        FROM escolas e
        LEFT JOIN municipios m ON m.codigo_ibge = e.codigo_ibge::text
        LEFT JOIN isocronas_json i ON i.co_entidade = e.co_entidade
        LEFT JOIN antt_od o ON o.codigo_ibge_origem = e.codigo_ibge::text OR o.codigo_ibge_destino = e.codigo_ibge::text
        LEFT JOIN renavam rnv ON rnv.codigo_ibge = e.codigo_ibge::text
        LEFT JOIN snv_vmda v ON v.codigo_ibge = e.codigo_ibge::text
        LEFT JOIN antt_acidentes a ON a.codigo_ibge = e.codigo_ibge::text
        LEFT JOIN renaest re ON re.codigo_ibge = e.codigo_ibge::text
        LEFT JOIN recife_transporte rt ON rt.co_entidade = e.co_entidade
        GROUP BY
            e.co_entidade, e.no_entidade, e.codigo_ibge, e.tp_dependencia,
            e.tp_localizacao, e.latitude, e.longitude, e.geom,
            m.nome_municipio, m.sigla_uf,
            rnv.total_frota, rnv.automoveis, rnv.moto, rnv.onibus,
            rt.vagas_transporte, rt.turno,
            i.isocronas_por_tempo
    )
SELECT
    co_entidade,
    no_entidade,
    codigo_ibge,
    municipio_escola,
    uf_escola,
    tp_dependencia,
    tp_localizacao,
    latitude,
    longitude,
    geom,
    isocronas_por_tempo,
    antt_od_saida,
    antt_od_entrada,
    renavam_total_frota,
    renavam_automoveis,
    renavam_moto,
    renavam_onibus,
    vmda_total_municipio,
    vmda_leve_municipio,
    vmda_pesado_municipio,
    acidentes_12m,
    acidentes_fatais_12m,
    sinistros_12m,
    sinistros_fatais_12m,
    recife_vagas_transporte,
    recife_turno,
    -- Indicadores derivados
    CASE
        WHEN vmda_total_municipio > 0 AND acidentes_12m > 0
        THEN round(acidentes_fatais_12m::numeric / acidentes_12m * 100, 2)
    END AS pct_acidentes_fatais,
    CASE
        WHEN renavam_total_frota > 0
        THEN round(renavam_onibus::numeric / renavam_total_frota * 100, 2)
    END AS pct_onibus_frota,
    -- Indicadores de mobilidade escolar
    CASE
        WHEN isocronas_por_tempo IS NOT NULL THEN 'coberto'
        ELSE 'sem_isocrona'
    END AS status_isocrona,
    CASE
        WHEN (antt_od_saida IS NOT NULL AND jsonb_array_length(antt_od_saida) > 0) OR
             (antt_od_entrada IS NOT NULL AND jsonb_array_length(antt_od_entrada) > 0)
        THEN 'conectado_antt'
        ELSE 'sem_conexao_antt'
    END AS status_conexao_antt,
    CURRENT_DATE AS computed_at
FROM escola_metricas;

-- Comentários
COMMENT ON VIEW analytics.mobilidade_escola IS 'Mobilidade escolar consolidada: isocronas (OSRM/Valhalla), ANTT OD, RENAVAM frota, acidentes ANTT, RENAEST sinistros, SNV/VMDA, Recife transporte escolar. Uma linha por escola.';

COMMIT;
