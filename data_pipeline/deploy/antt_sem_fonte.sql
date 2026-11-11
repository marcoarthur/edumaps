-- Deploy edumaps:antt_sem_fonte to pg
-- requires: antt_acidente_geolocalizacao
-- requires: analytics_views_materializadas
-- requires: analytics_ausencia_visivel
--
-- #168: três tabelas da ANTT foram desenhadas para dados que a ANTT não
-- publica, e ficaram vazias desde a criação (2026-10-01):
--
--   * antt_trecho_geodados — geometria de TRECHO (LineString). O portal só
--     publica pontos de km; a localização do acidente passou a usá-los
--     (change antt_acidente_geolocalizacao).
--   * antt_contagem_equipamento — FK para um código de trecho que a fonte de
--     volume (radar/SAT) não traz.
--   * antt_od_municipio — matriz OD do MONITRIIP, que é grão de viagem
--     individual (CNPJ, placa, IMEI); negada na allowlist por LGPD.
--
-- Decisão do developer (2026-11-11): remover as três, em vez de mantê-las
-- prometendo um dado que não existe. Remove também o que só existia por
-- causa delas na analytics.mobilidade_escola: as colunas antt_od_saida,
-- antt_od_entrada e status_conexao_antt.
--
-- Os acidentes passam a chegar à escola pelo município do próprio acidente
-- (antes: JOIN com antt_trecho_geodados, sempre vazio).
--
-- A matview é recriada com a definição nova (a fachada analytics.mobilidade_escola
-- continua a ser SELECT * da matview, como na #158). A definição deixa de vir
-- de pg_get_viewdef: a view antiga já não existe como lógica, só como fachada.
-- snv_trecho_vmda declara `requires: antt_trecho_geodados` no plano, mas não
-- tem FK nem junção com ela; fica como está.

BEGIN;

DROP VIEW analytics.mobilidade_escola;
DROP MATERIALIZED VIEW analytics.mv_mobilidade_escola;

CREATE MATERIALIZED VIEW analytics.mv_mobilidade_escola AS
WITH
    -- Contagem de registos por fonte (ver comentário no topo).
    fontes AS (
        SELECT
            (SELECT COUNT(*) FROM clean.isocrona_escolar)          AS n_isocrona,
            (SELECT COUNT(*) FROM clean.renavam_frota_municipio)   AS n_renavam,
            (SELECT COUNT(*) FROM clean.snv_trecho_vmda)           AS n_vmda,
            -- Acidentes: só os LOCALIZADOS num município contam como fonte.
            -- Carregados sem marcos de km, não há o que dizer por município:
            -- o indicador fica NULL, não 0 (#154).
            (SELECT COUNT(*) FROM clean.antt_acidente_trecho
              WHERE codigo_ibge IS NOT NULL)                       AS n_acidentes,
            (SELECT COUNT(*) FROM clean.renaest_sinistro)          AS n_renaest,
            (SELECT COUNT(*) FROM clean.recife_transporte_escolar) AS n_recife
    ),
    escolas AS (
        SELECT
            e.co_entidade,
            e.no_entidade,
            e.co_municipio AS codigo_ibge,
            e.tp_dependencia,
            e.tp_localizacao,
            e.latitude,
            e.longitude,
            ST_SetSRID(ST_MakePoint(e.longitude, e.latitude), 4674) AS geom
        FROM clean.censo_escolas e
        WHERE e.tp_situacao_funcionamento = 1
          AND e.latitude IS NOT NULL
          AND e.longitude IS NOT NULL
          AND e.nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_escolas)
    ),
    municipios AS (
        SELECT m.codigo_ibge, m.nome_municipio, m.sigla_uf
        FROM clean.malha_municipio m
    ),
    -- Isocronas: uma linha por escola.
    isocronas_escola AS (
        SELECT
            co_entidade,
            jsonb_object_agg(
                tempo_minutos::text,
                jsonb_build_object('grid_count', grid_count,
                                   'populacao_total', populacao_total)
            ) AS isocronas_por_tempo
        FROM (
            SELECT
                co_entidade,
                tempo_minutos,
                COUNT(DISTINCT grid_id) AS grid_count,
                SUM(populacao_grade)    AS populacao_total
            FROM clean.isocrona_escolar
            WHERE dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.isocrona_escolar)
            GROUP BY co_entidade, tempo_minutos
        ) agg
        GROUP BY co_entidade
    ),
    -- RENAVAM: uma linha por município. A tabela tem ano/mês dentro do
    -- snapshot; sem DISTINCT ON a view produzia uma linha por
    -- (ano, mês, frota) e multiplicava o resto por fan-out.
    renavam_municipio AS (
        SELECT DISTINCT ON (r.codigo_ibge)
            r.codigo_ibge,
            r.ano,
            r.mes,
            r.total_frota,
            r.automoveis,
            r.moto,
            r.onibus
        FROM clean.renavam_frota_municipio r
        WHERE r.dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.renavam_frota_municipio)
        ORDER BY r.codigo_ibge, r.ano DESC, r.mes DESC
    ),
    -- Acidentes ANTT por município: uma linha por município. O município
    -- vem do próprio acidente (clean.antt_geolocalizar_acidentes, #168).
    acidentes_municipio AS (
        SELECT
            m.codigo_ibge,
            CASE WHEN f.n_acidentes = 0 THEN NULL
                 ELSE COALESCE(ac.acidentes_12m, 0) END AS acidentes_12m,
            CASE WHEN f.n_acidentes = 0 THEN NULL
                 ELSE COALESCE(ac.acidentes_fatais_12m, 0) END AS acidentes_fatais_12m
        FROM clean.malha_municipio m
        CROSS JOIN fontes f
        LEFT JOIN (
            -- O job substitui o recorte de cada concessionária, então a
            -- tabela inteira é o estado atual (sem filtro por dt_carga).
            -- Fatal = com morto: a fonte não classifica a ocorrência como
            -- 'fatal' (tipo_de_ocorrencia é 'com vítima'/'sem vítima').
            SELECT
                a.codigo_ibge,
                COUNT(*) FILTER (WHERE a.data_acidente >= CURRENT_DATE - INTERVAL '12 months')
                    AS acidentes_12m,
                COUNT(*) FILTER (WHERE a.mortos > 0
                                   AND a.data_acidente >= CURRENT_DATE - INTERVAL '12 months')
                    AS acidentes_fatais_12m
            FROM clean.antt_acidente_trecho a
            WHERE a.codigo_ibge IS NOT NULL
            GROUP BY a.codigo_ibge
        ) ac ON ac.codigo_ibge = m.codigo_ibge
    ),
    -- RENAEST sinistros por município: uma linha por município.
    sinistros_municipio AS (
        SELECT
            m.codigo_ibge,
            CASE WHEN f.n_renaest = 0 THEN NULL
                 ELSE COALESCE(si.sinistros_12m, 0) END AS sinistros_12m,
            CASE WHEN f.n_renaest = 0 THEN NULL
                 ELSE COALESCE(si.sinistros_fatais_12m, 0) END AS sinistros_fatais_12m
        FROM clean.malha_municipio m
        CROSS JOIN fontes f
        LEFT JOIN (
            SELECT
                codigo_ibge,
                COUNT(*) FILTER (WHERE data_sinistro >= CURRENT_DATE - INTERVAL '12 months')
                    AS sinistros_12m,
                COUNT(*) FILTER (WHERE classificacao ILIKE '%fatal%'
                                   AND data_sinistro >= CURRENT_DATE - INTERVAL '12 months')
                    AS sinistros_fatais_12m
            FROM clean.renaest_sinistro
            WHERE dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.renaest_sinistro)
              AND codigo_ibge IS NOT NULL
            GROUP BY codigo_ibge
        ) si ON si.codigo_ibge = m.codigo_ibge
    ),
    -- SNV/VMDA por município: uma linha por município.
    vmda_municipio AS (
        SELECT
            m.codigo_ibge,
            CASE WHEN f.n_vmda = 0 THEN NULL
                 ELSE COALESCE(vd.vmda_total, 0) END  AS vmda_total_municipio,
            CASE WHEN f.n_vmda = 0 THEN NULL
                 ELSE COALESCE(vd.vmda_leve, 0) END  AS vmda_leve_municipio,
            CASE WHEN f.n_vmda = 0 THEN NULL
                 ELSE COALESCE(vd.vmda_pesado, 0) END AS vmda_pesado_municipio
        FROM clean.malha_municipio m
        CROSS JOIN fontes f
        LEFT JOIN (
            SELECT
                codigo_ibge,
                SUM(vmda_total)  AS vmda_total,
                SUM(vmda_leve)   AS vmda_leve,
                SUM(vmda_pesado) AS vmda_pesado
            FROM clean.snv_trecho_vmda
            WHERE vmda_total IS NOT NULL
            GROUP BY codigo_ibge
        ) vd ON vd.codigo_ibge = m.codigo_ibge
    ),
    -- Transporte escolar do Recife: uma linha por escola, ano mais
    -- recente. A tabela tem uma linha por (escola, ano, turno); a
    -- versão anterior agrupava por turno e produzia fan-out.
    recife_escola AS (
        SELECT
            co_entidade,
            -- ::integer preserva o tipo declarado da coluna (integer) no
            -- contrato da view. O sum de vagas por escola não chega perto
            -- do limite; o cast existe só para não quebrar o
            -- CREATE OR REPLACE.
            SUM(vagas_transporte)::integer AS vagas_transporte,
            string_agg(DISTINCT turno, ', ' ORDER BY turno) AS turno
        FROM clean.recife_transporte_escolar
        WHERE dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.recife_transporte_escolar)
          AND ano = (SELECT MAX(ano) FROM clean.recife_transporte_escolar
                     WHERE dt_snapshot = (SELECT MAX(dt_snapshot)
                                         FROM clean.recife_transporte_escolar))
        GROUP BY co_entidade
    )
SELECT
    e.co_entidade,
    e.no_entidade,
    e.codigo_ibge,
    mu.nome_municipio AS municipio_escola,
    mu.sigla_uf      AS uf_escola,
    e.tp_dependencia,
    e.tp_localizacao,
    e.latitude,
    e.longitude,
    e.geom,
    -- Fonte vazia => NULL (não avaliável), não JSON vazio.
    CASE WHEN f.n_isocrona = 0 THEN NULL ELSE ie.isocronas_por_tempo END
        AS isocronas_por_tempo,
    CASE WHEN f.n_renavam = 0 THEN NULL ELSE rnv.total_frota END AS renavam_total_frota,
    CASE WHEN f.n_renavam = 0 THEN NULL ELSE rnv.automoveis END AS renavam_automoveis,
    CASE WHEN f.n_renavam = 0 THEN NULL ELSE rnv.moto END       AS renavam_moto,
    CASE WHEN f.n_renavam = 0 THEN NULL ELSE rnv.onibus END     AS renavam_onibus,
    vm.vmda_total_municipio,
    vm.vmda_leve_municipio,
    vm.vmda_pesado_municipio,
    ac.acidentes_12m,
    ac.acidentes_fatais_12m,
    si.sinistros_12m,
    si.sinistros_fatais_12m,
    CASE WHEN f.n_recife = 0 THEN NULL ELSE rt.vagas_transporte END AS recife_vagas_transporte,
    CASE WHEN f.n_recife = 0 THEN NULL ELSE rt.turno END            AS recife_turno,
    -- Indicadores derivados
    CASE
        WHEN ac.acidentes_fatais_12m IS NOT NULL AND ac.acidentes_12m > 0
        THEN round(ac.acidentes_fatais_12m::numeric / ac.acidentes_12m * 100, 2)
    END AS pct_acidentes_fatais,
    CASE
        WHEN rnv.total_frota IS NOT NULL AND rnv.total_frota > 0
        THEN round(rnv.onibus::numeric / rnv.total_frota * 100, 2)
    END AS pct_onibus_frota,
    -- Status: autoridade sobre a presença/ausência de dado.
    CASE
        WHEN f.n_isocrona = 0                 THEN 'fonte_vazia'
        WHEN ie.isocronas_por_tempo IS NOT NULL THEN 'coberto'
        ELSE 'sem_isocrona'
    END AS status_isocrona,
    CURRENT_DATE AS computed_at
FROM escolas e
CROSS JOIN fontes f
LEFT JOIN municipios mu        ON mu.codigo_ibge = e.codigo_ibge::text
LEFT JOIN isocronas_escola ie   ON ie.co_entidade = e.co_entidade
LEFT JOIN renavam_municipio rnv ON rnv.codigo_ibge = e.codigo_ibge::text
LEFT JOIN vmda_municipio vm     ON vm.codigo_ibge = e.codigo_ibge::text
LEFT JOIN acidentes_municipio ac ON ac.codigo_ibge = e.codigo_ibge::text
LEFT JOIN sinistros_municipio si ON si.codigo_ibge = e.codigo_ibge::text
LEFT JOIN recife_escola rt      ON rt.co_entidade = e.co_entidade;

;

CREATE UNIQUE INDEX mv_mobilidade_escola_pk ON analytics.mv_mobilidade_escola (co_entidade);

CREATE VIEW analytics.mobilidade_escola AS SELECT * FROM analytics.mv_mobilidade_escola;

COMMENT ON MATERIALIZED VIEW analytics.mv_mobilidade_escola IS
'Materialização de analytics.mobilidade_escola (#158), chave co_entidade. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real. Definição desde a change antt_sem_fonte (#168).';

COMMENT ON VIEW analytics.mobilidade_escola IS
'Mobilidade escolar consolidada: isocronas, RENAVAM frota, acidentes ANTT (por município do acidente), RENAEST sinistros, SNV/VMDA, Recife transporte escolar. Uma linha por escola. SEMÂNTICA DA AUSÊNCIA: todo indicador de contagem e soma sai NULL quando a respetiva fonte não tem snapshot, e 0 quando a fonte tem dado mas o município não tem. Para os acidentes, a fonte conta só os acidentes localizados num município: carregados sem marcos de km, acidentes_12m sai NULL. Status_isocrona acrescenta ''fonte_vazia'' como terceiro estado. Cada fonte é pré-agregada à sua grão (município ou escola) antes do join, para que nenhuma agregação seja multiplicada pelas linhas das outras fontes.';

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
    GRANT SELECT ON analytics.mv_mobilidade_escola, analytics.mobilidade_escola TO edumaps_leitor;
  END IF;
END
$$;

-- As três tabelas sem fonte (a de contagem primeiro: tem FK para a de trechos).
DROP TABLE clean.antt_contagem_equipamento;
DROP TABLE clean.antt_trecho_geodados;
DROP TABLE clean.antt_od_municipio;

DELETE FROM clean.import_metadata
 WHERE table_name IN ('clean.antt_contagem_equipamento',
                      'clean.antt_trecho_geodados',
                      'clean.antt_od_municipio');

COMMIT;
