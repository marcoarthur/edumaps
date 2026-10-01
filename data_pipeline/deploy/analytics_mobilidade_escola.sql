-- Deploy edumaps:analytics_mobilidade_escola to pg
-- requires: isocrona_escolar
-- requires: antt_od_municipio
-- requires: renavam_frota_municipio
-- requires: antt_contagem_equipamento
-- requires: snv_trecho_vmda
-- requires: renaest_sinistro
-- requires: renaest_localidade_municipio
-- requires: recife_transporte_escolar
-- requires: censo_escolas
-- requires: malha_municipio
-- requires: extensions

BEGIN;

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