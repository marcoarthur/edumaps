-- Revert edumaps:antt_sem_fonte from pg
--
-- Recria as três tabelas como estavam (vazias: nunca tiveram fonte) e a
-- matview com a definição anterior (analytics_ausencia_visivel).

BEGIN;

DROP VIEW analytics.mobilidade_escola;
DROP MATERIALIZED VIEW analytics.mv_mobilidade_escola;

-- antt_od_municipio
-- =================================================================
-- ANTT MONITRIIP - MATRIZ OD MUNICÍPIO × MUNICÍPIO × MÊS
-- Fonte: dados.antt.gov.br/dataset/monitriip-servico-regular
-- Única matriz OD nacional com chave município-município, mensal desde jan/2019
-- Supressão OBRIGATÓRIA: quantidade_bilhetes < 10 ANTES de qualquer agregação
-- tipo_gratuidade FORA da camada analítica (indutor de reidentificação)
-- =================================================================

DROP TABLE IF EXISTS clean.antt_od_municipio;
CREATE TABLE clean.antt_od_municipio (
    codigo_ibge_origem    TEXT NOT NULL,      -- 7 dígitos IBGE (origem)
    codigo_ibge_destino   TEXT NOT NULL,      -- 7 dígitos IBGE (destino)
    mes_viagem            DATE NOT NULL,      -- primeiro dia do mês (ex.: 2019-01-01)
    quantidade_bilhetes   INTEGER,            -- quantidade de bilhetes (suprimido se < 10)
    supressao_aplicada    BOOLEAN DEFAULT FALSE, -- TRUE = valor suprimido (count < 10)
    -- Metadados
    dt_snapshot           DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_antt_od_municipio PRIMARY KEY (codigo_ibge_origem, codigo_ibge_destino, mes_viagem, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_od_origem ON clean.antt_od_municipio (codigo_ibge_origem);
CREATE INDEX IF NOT EXISTS idx_antt_od_destino ON clean.antt_od_municipio (codigo_ibge_destino);
CREATE INDEX IF NOT EXISTS idx_antt_od_mes ON clean.antt_od_municipio (mes_viagem);
CREATE INDEX IF NOT EXISTS idx_antt_od_dt_snapshot ON clean.antt_od_municipio (dt_snapshot);

-- FKs para malha_municipio
ALTER TABLE clean.antt_od_municipio
  ADD CONSTRAINT fk_antt_od_origem
  FOREIGN KEY (codigo_ibge_origem) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

ALTER TABLE clean.antt_od_municipio
  ADD CONSTRAINT fk_antt_od_destino
  FOREIGN KEY (codigo_ibge_destino) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.antt_od_municipio IS 'ANTT MONITRIIP - Matriz OD município × município × mês (ônibus rodoviário intermunicipal). Supressão OBRIGATÓRIA: quantidade_bilhetes < 10 ANTES de qualquer agregação. tipo_gratuidade FORA da camada analítica. Série mensal desde jan/2019.';
COMMENT ON COLUMN clean.antt_od_municipio.codigo_ibge_origem IS 'Código IBGE do município de origem (7 dígitos)';
COMMENT ON COLUMN clean.antt_od_municipio.codigo_ibge_destino IS 'Código IBGE do município de destino (7 dígitos)';
COMMENT ON COLUMN clean.antt_od_municipio.mes_viagem IS 'Mês de referência (primeiro dia do mês)';
COMMENT ON COLUMN clean.antt_od_municipio.quantidade_bilhetes IS 'Quantidade de bilhetes (suprimido se < 10)';
COMMENT ON COLUMN clean.antt_od_municipio.supressao_aplicada IS 'TRUE = valor suprimido por supressão de célula pequena (count < 10)';
COMMENT ON COLUMN clean.antt_od_municipio.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_od_municipio'::text,
       'API ANTT MONITRIIP'::text,
       'https://dados.antt.gov.br/dataset/monitriip-servico-regular'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_od_municipio. Supressão count < 10 obrigatória. tipo_gratuidade excluído. CSV ISO-8859-1, delimitador ;.'
FROM clean.antt_od_municipio;

-- antt_trecho_geodados
-- =================================================================
-- ANTT - GEODADOS DE TRECHOS RODOVIÁRIOS (trecho → município)
-- Fonte: dados.antt.gov.br/dataset/trechos
-- RESOLVE: trecho → município (via Concessionaria;Trecho;Km_Inicial;Km_Final;Municipio)
-- =================================================================

DROP TABLE IF EXISTS clean.antt_trecho_geodados;
CREATE TABLE clean.antt_trecho_geodados (
    concessionaria        TEXT NOT NULL,
    trecho                TEXT NOT NULL,        -- código do trecho
    km_inicial            NUMERIC(10,3),
    km_final              NUMERIC(10,3),
    extensao_km           NUMERIC(10,3),
    uf                    CHAR(2),
    municipio             TEXT,                 -- nome do município
    codigo_ibge           TEXT,                 -- 7 dígitos IBGE (quando disponível)
    -- Geometria do trecho (linestring)
    geometry              geometry(LineString, 4674),

    CONSTRAINT pk_antt_trecho_geodados PRIMARY KEY (concessionaria, trecho)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_trecho_codigo_ibge ON clean.antt_trecho_geodados (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_antt_trecho_geometry ON clean.antt_trecho_geodados USING GIST (geometry);

-- FK para malha_municipio
ALTER TABLE clean.antt_trecho_geodados
  ADD CONSTRAINT fk_antt_trecho_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE SET NULL;

-- Unique constraint on trecho for FK from antt_contagem_equipamento
ALTER TABLE clean.antt_trecho_geodados
  ADD CONSTRAINT uq_antt_trecho_geodados_trecho UNIQUE (trecho);

-- Comentários
COMMENT ON TABLE clean.antt_trecho_geodados IS 'Geodados ANTT de trechos rodoviários — resolve trecho → município (código IBGE). JOIN OBRIGATÓRIO com antt_acidente_trecho para resolver município do acidente.';
COMMENT ON COLUMN clean.antt_trecho_geodados.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.antt_trecho_geodados.trecho IS 'Código do trecho (chave de join com antt_acidente_trecho)';
COMMENT ON COLUMN clean.antt_trecho_geodados.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.antt_trecho_geodados.geometry IS 'Geometria do trecho (LineString, SRID 4674)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_trecho_geodados'::text,
       'API ANTT trechos'::text,
       'https://dados.antt.gov.br/dataset/trechos'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_trecho_geodados. Resolve trecho → município para antt_acidente_trecho.'
FROM clean.antt_trecho_geodados;

-- antt_contagem_equipamento
-- =================================================================
-- ANTT - CONTAGEM DE TRÁFEGO EM EQUIPAMENTOS DE MEDIÇÃO
-- Fonte: dados.antt.gov.br (painel/conjunto de dados de contagem)
-- Exposição a ruído e tráfego em trecho, com coordenada
-- Somente rodovias federais concedidas
-- =================================================================

DROP TABLE IF EXISTS clean.antt_contagem_equipamento;
CREATE TABLE clean.antt_contagem_equipamento (
    id_contagem           BIGSERIAL PRIMARY KEY,
    concessionaria        TEXT NOT NULL,
    trecho                TEXT NOT NULL,        -- código do trecho (FK para antt_trecho_geodados)
    km                    NUMERIC(10,3),
    latitude              NUMERIC(10,8),
    longitude             NUMERIC(11,8),
    -- Dados de tráfego
    data_contagem         DATE NOT NULL,
    volume_diario         INTEGER,              -- volume médio diário
    composicao_leve       INTEGER,              -- veículos leves
    composicao_pesado     INTEGER,              -- veículos pesados
    -- Metadados
    dt_carga              TIMESTAMPTZ DEFAULT NOW(),
    dt_snapshot           DATE NOT NULL,        -- data do snapshot mensal

    CONSTRAINT uq_antt_contagem UNIQUE (concessionaria, trecho, data_contagem, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_contagem_trecho ON clean.antt_contagem_equipamento (trecho);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_data ON clean.antt_contagem_equipamento (data_contagem);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_dt_snapshot ON clean.antt_contagem_equipamento (dt_snapshot);
CREATE INDEX IF NOT EXISTS idx_antt_contagem_geometry ON clean.antt_contagem_equipamento USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4674)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- FK para antt_trecho_geodados
ALTER TABLE clean.antt_contagem_equipamento
  ADD CONSTRAINT fk_antt_contagem_trecho
  FOREIGN KEY (trecho) REFERENCES clean.antt_trecho_geodados(trecho)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.antt_contagem_equipamento IS 'ANTT contagem de tráfego em equipamentos de medição. Somente rodovias federais concedidas. JOIN com antt_trecho_geodados para município.';
COMMENT ON COLUMN clean.antt_contagem_equipamento.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.antt_contagem_equipamento.trecho IS 'Código do trecho (FK para antt_trecho_geodados)';
COMMENT ON COLUMN clean.antt_contagem_equipamento.data_contagem IS 'Data da contagem';
COMMENT ON COLUMN clean.antt_contagem_equipamento.volume_diario IS 'Volume médio diário de veículos';
COMMENT ON COLUMN clean.antt_contagem_equipamento.composicao_leve IS 'Veículos leves';
COMMENT ON COLUMN clean.antt_contagem_equipamento.composicao_pesado IS 'Veículos pesados';
COMMENT ON COLUMN clean.antt_contagem_equipamento.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_contagem_equipamento'::text,
       'API ANTT contagem de tráfego'::text,
       'https://dados.antt.gov.br'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_contagem_equipamento. Somente rodovias concedidas. KMZ requer GDAL/ogr - pré-converter para GPKG.'
FROM clean.antt_contagem_equipamento;

CREATE MATERIALIZED VIEW analytics.mv_mobilidade_escola AS
WITH
    -- Contagem de registos por fonte (ver comentário no topo).
    fontes AS (
        SELECT
            (SELECT COUNT(*) FROM clean.isocrona_escolar)          AS n_isocrona,
            (SELECT COUNT(*) FROM clean.antt_od_municipio)         AS n_od,
            (SELECT COUNT(*) FROM clean.renavam_frota_municipio)   AS n_renavam,
            (SELECT COUNT(*) FROM clean.snv_trecho_vmda)           AS n_vmda,
            (SELECT COUNT(*) FROM clean.antt_acidente_trecho)      AS n_acidentes,
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
    -- OD ANTT: uma linha por município, em cada direção.
    od_saida AS (
        SELECT
            codigo_ibge_origem AS codigo_ibge,
            jsonb_agg(jsonb_build_object(
                'destino_ibge', codigo_ibge_destino,
                'bilhetes', quantidade_bilhetes,
                'mes', to_char(mes_viagem, 'YYYY-MM')
            )) AS antt_od_saida
        FROM clean.antt_od_municipio
        WHERE dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.antt_od_municipio)
          AND supressao_aplicada = FALSE
        GROUP BY codigo_ibge_origem
    ),
    od_entrada AS (
        SELECT
            codigo_ibge_destino AS codigo_ibge,
            jsonb_agg(jsonb_build_object(
                'origem_ibge', codigo_ibge_origem,
                'bilhetes', quantidade_bilhetes,
                'mes', to_char(mes_viagem, 'YYYY-MM')
            )) AS antt_od_entrada
        FROM clean.antt_od_municipio
        WHERE dt_snapshot = (SELECT MAX(dt_snapshot) FROM clean.antt_od_municipio)
          AND supressao_aplicada = FALSE
        GROUP BY codigo_ibge_destino
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
    -- Acidentes ANTT por município: uma linha por município.
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
            SELECT
                t.codigo_ibge,
                COUNT(*) FILTER (WHERE a.data_acidente >= CURRENT_DATE - INTERVAL '12 months')
                    AS acidentes_12m,
                COUNT(*) FILTER (WHERE a.classificacao ILIKE '%fatal%'
                                   AND a.data_acidente >= CURRENT_DATE - INTERVAL '12 months')
                    AS acidentes_fatais_12m
            FROM clean.antt_acidente_trecho a
            JOIN clean.antt_trecho_geodados t ON t.trecho = a.trecho
            WHERE a.dt_carga = (SELECT MAX(dt_carga) FROM clean.antt_acidente_trecho)
            GROUP BY t.codigo_ibge
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
    CASE WHEN f.n_od = 0 THEN NULL ELSE os.antt_od_saida END   AS antt_od_saida,
    CASE WHEN f.n_od = 0 THEN NULL ELSE oe.antt_od_entrada END AS antt_od_entrada,
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
    CASE
        WHEN f.n_od = 0                        THEN 'fonte_vazia'
        WHEN os.antt_od_saida IS NOT NULL OR oe.antt_od_entrada IS NOT NULL
        THEN 'conectado_antt'
        ELSE 'sem_conexao_antt'
    END AS status_conexao_antt,
    CURRENT_DATE AS computed_at
FROM escolas e
CROSS JOIN fontes f
LEFT JOIN municipios mu        ON mu.codigo_ibge = e.codigo_ibge::text
LEFT JOIN isocronas_escola ie   ON ie.co_entidade = e.co_entidade
LEFT JOIN od_saida os           ON os.codigo_ibge = e.codigo_ibge::text
LEFT JOIN od_entrada oe         ON oe.codigo_ibge = e.codigo_ibge::text
LEFT JOIN renavam_municipio rnv ON rnv.codigo_ibge = e.codigo_ibge::text
LEFT JOIN vmda_municipio vm     ON vm.codigo_ibge = e.codigo_ibge::text
LEFT JOIN acidentes_municipio ac ON ac.codigo_ibge = e.codigo_ibge::text
LEFT JOIN sinistros_municipio si ON si.codigo_ibge = e.codigo_ibge::text
LEFT JOIN recife_escola rt      ON rt.co_entidade = e.co_entidade;

CREATE UNIQUE INDEX mv_mobilidade_escola_pk ON analytics.mv_mobilidade_escola (co_entidade);

CREATE VIEW analytics.mobilidade_escola AS SELECT * FROM analytics.mv_mobilidade_escola;

COMMENT ON MATERIALIZED VIEW analytics.mv_mobilidade_escola IS
'Materialização de analytics.mobilidade_escola (#158): mesma definição, chave co_entidade. Refrescada por analytics.refresh_views_ingestao() ao fim de cada carga real.';

COMMENT ON VIEW analytics.mobilidade_escola IS
'Mobilidade escolar consolidada: isocronas (OSRM/Valhalla), ANTT OD, RENAVAM frota, acidentes ANTT, RENAEST sinistros, SNV/VMDA, Recife transporte escolar. Uma linha por escola. SEMÂNTICA DA AUSÊNCIA: todo indicador de contagem e soma sai NULL quando a respetiva fonte não tem snapshot, e 0 quando a fonte tem dado mas o município não tem. Status_isocrona e status_conexao_antt acrescentam ''fonte_vazia'' como terceiro estado, para que o consumidor nunca tenha de inferir a causa a partir do valor. Cada fonte é pré-agregada à sua grão (município ou escola) antes do join, para que nenhuma agregação seja multiplicada pelas linhas das outras fontes.';

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
    GRANT SELECT ON analytics.mv_mobilidade_escola, analytics.mobilidade_escola TO edumaps_leitor;
  END IF;
END
$$;

COMMIT;
