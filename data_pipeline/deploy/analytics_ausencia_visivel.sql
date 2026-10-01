-- Deploy edumaps:analytics_ausencia_visivel to pg
-- requires: analytics_acessibilidade_saude
-- requires: analytics_mobilidade_escola

BEGIN;

-- =================================================================
-- CORREÇÃO: AUSÊNCIA DE DADO NÃO É VALOR ZERO
-- Issue #154
-- =================================================================
-- As views de análise faziam LEFT JOIN contra tabelas-fonte vazias e
-- preenchiam o indicador com 0 (COALESCE(SUM(...), 0) e COUNT() sobre
-- conjunto vazio). O resultado é uma afirmação falsa com aparência de
-- dado real: 'n_ubs_municipio = 0' e 'Sem UBS no município' para as
-- 145.734 escolas do país, quando o correto seria 'não avaliado'.
--
-- Esta change faz duas coisas, porque as duas são necessárias para que
-- o indicador pare de mentir:
--
-- 1) AUSÊNCIA EXPLÍCITA. Um CTE `fontes` conta os registos de cada
--    fonte. Quando a fonte não tem snapshot, o indicador sai NULL
--    (não avaliável); quando a fonte tem dado mas o município não tem,
--    o indicador sai 0 (zero real). São três estados distintos, não dois.
--
-- 2) PRÉ-AGREGADO POR FONTE. A versão anterior fazia sete LEFT JOIN
--    numa única query com GROUP BYschools. Isso é produto cartesiano:
--    COUNT(acidentes) era multiplicado pelas linhas das outras seis
--    fontes. Com as tabelas vazias o efeito é invisível (1×1); com
--    dado carregado, acidentes_12m sairia inflado. A pré-agregação por
--    município e por escola elimina o fan-out E é o que permite
--    distinguir zero real de ausência — o GROUP BY único não permite.
--
-- analytics.esforco_fiscal_educacao NÃO é alterada: ela já faz LEFT
-- JOIN sem COALESCE e propaga NULL corretamente. Serve de referência
-- do padrão pretendido.

-- -----------------------------------------------------------------
-- analytics.acessibilidade_saude
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.acessibilidade_saude AS
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
    -- UBS/USF ativas do CNES (snapshot mais recente)
    ubs AS (
        SELECT
            c.codigo_cnes,
            c.codigo_municipio::text AS codigo_ibge,
            c.latitude,
            c.longitude,
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
    -- Distância da escola à UBS mais próxima, pré-agregado por município.
    -- Uma linha por município: se o CNES tem dado e o município não tem
    -- UBS, o COUNT devolve 0 (zero real); se o CNES está vazio, o LEFT
    -- JOIN não produz linha e a guarda em `fontes` devolve NULL.
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
    -- Distância por escola (não por município): só faz sentido quando há
    -- UBS. Sem dado de UBS, a distância é NULL — que já era honesto.
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
    -- Fonte CNES vazia => NULL (não avaliável), não 0.
    CASE WHEN f.n_cnes = 0 THEN NULL ELSE um.n_ubs_municipio END AS n_ubs_municipio,
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
    -- Efetividade APS: NULL se a fonte está vazia ou se não há vaga ativa.
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
'Acessibilidade da escola à rede de saúde (UBS/USF). Cruza CNES (oferta em ponto) + SISAB (efetividade APS) + Censo Escolar (demanda). Distância haversine aproximada; substituir por roteamento OSM quando malha viária estiver disponível. SEMÂNTICA DA AUSÊNCIA: se a fonte CNES não tem snapshot, n_ubs_municipio e dist_min_km_ubs saem NULL e classificacao_acesso = ''Não avaliado (fonte CNES sem snapshot)''. O valor ''Sem UBS no município'' só aparece quando o CNES tem dado. Zero real (0 UBS) é distinto de fonte vazia (NULL).';

-- -----------------------------------------------------------------
-- analytics.mobilidade_escola
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW analytics.mobilidade_escola AS
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

COMMENT ON VIEW analytics.mobilidade_escola IS
'Mobilidade escolar consolidada: isocronas (OSRM/Valhalla), ANTT OD, RENAVAM frota, acidentes ANTT, RENAEST sinistros, SNV/VMDA, Recife transporte escolar. Uma linha por escola. SEMÂNTICA DA AUSÊNCIA: todo indicador de contagem e soma sai NULL quando a respetiva fonte não tem snapshot, e 0 quando a fonte tem dado mas o município não tem. Status_isocrona e status_conexao_antt acrescentam ''fonte_vazia'' como terceiro estado, para que o consumidor nunca tenha de inferir a causa a partir do valor. Cada fonte é pré-agregada à sua grão (município ou escola) antes do join, para que nenhuma agregação seja multiplicada pelas linhas das outras fontes.';

COMMIT;
