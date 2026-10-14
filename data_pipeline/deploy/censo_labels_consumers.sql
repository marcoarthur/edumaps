-- Deploy edumaps:censo_labels_consumers to pg
-- requires: censo_label
-- requires: badge_functions
-- requires: rede_escolas_etapas
--
-- Consumers dos rótulos do Censo (issue #228). Onde antes havia um CASE à mão
-- (`WHEN 1 THEN 'Federal'`, `WHEN 1 THEN 'federal'`), agora o rótulo vem de
-- clean.censo_label()/clean.censo_code() — a mesma fonte do backend (#134).
--
-- 1. clean.typification_badge: dependência e localização pelo dicionário.
-- 2. analytics.mv_rede_escolas: `rede` (rótulo) pelo dicionário e o mapeamento
--    de volta (rótulo -> código, no pivô do IDEB) por clean.censo_code().
--
-- Os ícones (dep_icon/loc_icon) NÃO são rótulos e continuam no código: o
-- dicionário só guarda o texto.

BEGIN;

-- =================================================================
-- 1. typification_badge — rótulos do dicionário
-- =================================================================
CREATE OR REPLACE FUNCTION clean.typification_badge(p_co_entidade bigint)
RETURNS JSON AS $$
DECLARE
    result_json JSON;
    dep_text TEXT;
    loc_text TEXT;
    dep_icon TEXT;
    loc_icon TEXT;
    row_record RECORD;
BEGIN
    SELECT
        tp_dependencia,
        tp_localizacao
    INTO row_record
    FROM clean.censo_escolas
    WHERE co_entidade = p_co_entidade;

    IF NOT FOUND THEN
        RETURN '{}'::JSON;
    END IF;

    -- Rótulos: fonte canônica (clean.censo_data_dictionary).
    dep_text := COALESCE(
        clean.censo_label('clean.censo_escolas', 'tp_dependencia', row_record.tp_dependencia::text),
        'Não informada'
    );
    loc_text := COALESCE(
        clean.censo_label('clean.censo_escolas', 'tp_localizacao', row_record.tp_localizacao::text),
        'Não informada'
    );

    -- Ícones: apresentação, não rótulo canônico.
    dep_icon := CASE row_record.tp_dependencia
        WHEN 1 THEN '🏛️'
        WHEN 2 THEN '🏢'
        WHEN 3 THEN '🏙️'
        WHEN 4 THEN '🏫'
        ELSE '❓'
    END;
    loc_icon := CASE row_record.tp_localizacao
        WHEN 1 THEN '🏙️'
        WHEN 2 THEN '🌾'
        ELSE '❓'
    END;

    result_json := JSON_BUILD_OBJECT(
        'icone_principal', dep_icon,
        'label_principal', dep_text,
        'icone_localizacao', loc_icon,
        'label_localizacao', loc_text
    );

    RETURN result_json;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- 2. mv_rede_escolas — `rede` e o pivô do IDEB pelo dicionário
-- =================================================================
-- Mesma definição de rede_escolas_etapas, trocando os CASE de rótulo pelos
-- helpers. DROP + CREATE: materialized view não aceita CREATE OR REPLACE.
DROP MATERIALIZED VIEW analytics.mv_rede_escolas;

CREATE MATERIALIZED VIEW analytics.mv_rede_escolas AS
WITH
-- Base de municípios + rede (administração)
rede_base AS (
    SELECT DISTINCT
        co_municipio,
        tp_dependencia,
        no_municipio,
        sg_uf,
        no_regiao
    FROM clean.censo_escolas
    WHERE co_municipio IS NOT NULL AND tp_dependencia IS NOT NULL
),

-- Agregados de escolas e matrículas (Censo Escolar 2025)
escolas_agregado AS (
    SELECT
        e.co_municipio,
        e.tp_dependencia,
        COUNT(DISTINCT e.co_entidade) AS total_escolas,
        SUM(COALESCE(e.nro_etapas, 0)) AS total_etapas,
        ROUND(AVG(COALESCE(e.nro_etapas, 0))::NUMERIC, 1) AS media_etapas,
        SUM(COALESCE(m.qt_mat_bas, 0)) AS total_matriculas,
        SUM(COALESCE(m.qt_mat_inf, 0)) AS matriculas_infantil,
        SUM(COALESCE(m.qt_mat_fund, 0)) AS matriculas_fundamental,
        SUM(COALESCE(m.qt_mat_fund_ai, 0)) AS matriculas_fundamental_ai,
        SUM(COALESCE(m.qt_mat_fund_af, 0)) AS matriculas_fundamental_af,
        SUM(COALESCE(m.qt_mat_med, 0)) AS matriculas_medio,
        SUM(COALESCE(m.qt_mat_prof, 0)) AS matriculas_profissional,
        SUM(COALESCE(m.qt_mat_eja, 0)) AS matriculas_eja,
        SUM(COALESCE(m.qt_mat_esp, 0)) AS matriculas_especial,
        SUM(COALESCE(m.qt_mat_bas_int, 0)) AS matriculas_integral,
        SUM(COALESCE(d.qt_doc_bas, 0)) AS total_docentes,
        SUM(COALESCE(d.qt_doc_bas_esco_sup_grad, 0)) AS docentes_superior,
        SUM(COALESCE(d.qt_doc_bas_vinculo_concur, 0)) AS docentes_concursados
    FROM clean.censo_escolas e
    LEFT JOIN clean.censo_matriculas m
      ON m.co_entidade = e.co_entidade AND m.nu_ano_censo = 2025
    LEFT JOIN clean.censo_docentes d
      ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = 2025
    WHERE e.co_municipio IS NOT NULL AND e.tp_dependencia IS NOT NULL
    GROUP BY e.co_municipio, e.tp_dependencia
),

-- Último ano disponível por município + rede + etapa (IDEB/SAEB)
ultimo_ano_ideb AS (
    SELECT co_municipio, rede, etapa, MAX(ano) AS ano
    FROM clean.ideb_notas_escolas
    WHERE ideb_observado IS NOT NULL
    GROUP BY co_municipio, rede, etapa
),

-- Agregados de desempenho: média dos indicadores das escolas da rede no último ano
ideb_agregado AS (
    SELECT
        i.co_municipio,
        i.rede,
        i.etapa,
        ROUND(AVG(i.ideb_observado)::NUMERIC, 2) AS ideb_medio,
        ROUND(AVG(i.nota_media)::NUMERIC, 2) AS nota_media,
        ROUND(AVG(i.nota_matematica)::NUMERIC, 2) AS nota_matematica,
        ROUND(AVG(i.nota_portugues)::NUMERIC, 2) AS nota_portugues,
        MAX(i.ano) AS ano_ideb
    FROM clean.ideb_notas_escolas i
    JOIN ultimo_ano_ideb u
      ON u.co_municipio = i.co_municipio
     AND u.rede = i.rede
     AND u.etapa = i.etapa
     AND u.ano = i.ano
    WHERE i.ideb_observado IS NOT NULL
    GROUP BY i.co_municipio, i.rede, i.etapa
),

-- Pivô: indicadores por etapa em colunas. O `rede` do IDEB é um rótulo
-- ('Federal'); clean.censo_code() devolve o código do dicionário.
ideb_pivot AS (
    SELECT
        co_municipio,
        clean.censo_code('clean.censo_escolas', 'tp_dependencia', LOWER(rede))::int AS tp_dependencia,
        MAX(CASE WHEN etapa = 'fundamental_i' THEN ideb_medio END) AS ideb_fund_i,
        MAX(CASE WHEN etapa = 'fundamental_ii' THEN ideb_medio END) AS ideb_fund_ii,
        MAX(CASE WHEN etapa = 'ensino_medio' THEN ideb_medio END) AS ideb_medio,
        MAX(CASE WHEN etapa = 'fundamental_ii' THEN nota_media END) AS nota_media_fund_ii,
        MAX(CASE WHEN etapa = 'fundamental_ii' THEN nota_matematica END) AS nota_matematica_fund_ii,
        MAX(CASE WHEN etapa = 'fundamental_ii' THEN nota_portugues END) AS nota_portugues_fund_ii,
        MAX(CASE WHEN etapa = 'ensino_medio' THEN nota_media END) AS nota_media_medio,
        MAX(ano_ideb) AS ano_ideb
    FROM ideb_agregado
    WHERE clean.censo_code('clean.censo_escolas', 'tp_dependencia', LOWER(rede)) IS NOT NULL
    GROUP BY co_municipio, LOWER(rede)
)

-- SELECT final
SELECT
    rb.co_municipio::text,
    rb.no_municipio,
    rb.sg_uf,
    rb.no_regiao,
    rb.tp_dependencia AS codigo_rede,
    LOWER(clean.censo_label('clean.censo_escolas', 'tp_dependencia', rb.tp_dependencia::text)) AS rede,

    -- Escolas
    COALESCE(ea.total_escolas, 0) AS total_escolas,

    -- Etapas
    COALESCE(ea.total_etapas, 0) AS total_etapas,
    ea.media_etapas AS media_etapas,

    -- Matrículas
    COALESCE(ea.total_matriculas, 0) AS total_matriculas,
    COALESCE(ea.matriculas_infantil, 0) AS matriculas_infantil,
    COALESCE(ea.matriculas_fundamental, 0) AS matriculas_fundamental,
    COALESCE(ea.matriculas_fundamental_ai, 0) AS matriculas_fundamental_ai,
    COALESCE(ea.matriculas_fundamental_af, 0) AS matriculas_fundamental_af,
    COALESCE(ea.matriculas_medio, 0) AS matriculas_medio,
    COALESCE(ea.matriculas_profissional, 0) AS matriculas_profissional,
    COALESCE(ea.matriculas_eja, 0) AS matriculas_eja,
    COALESCE(ea.matriculas_especial, 0) AS matriculas_especial,
    COALESCE(ea.matriculas_integral, 0) AS matriculas_integral,

    -- Professores
    COALESCE(ea.total_docentes, 0) AS total_docentes,
    COALESCE(ea.docentes_superior, 0) AS docentes_superior,
    COALESCE(ea.docentes_concursados, 0) AS docentes_concursados,

    -- Desempenho
    ip.ideb_fund_i,
    ip.ideb_fund_ii,
    ip.ideb_medio,
    ip.nota_media_fund_ii,
    ip.nota_matematica_fund_ii,
    ip.nota_portugues_fund_ii,
    ip.nota_media_medio,
    ip.ano_ideb,

    -- Indicadores derivados
    CASE
        WHEN COALESCE(ea.total_docentes, 0) > 0
        THEN ROUND(COALESCE(ea.total_matriculas, 0)::NUMERIC / ea.total_docentes, 1)
        ELSE NULL
    END AS alunos_por_docente,

    CASE
        WHEN COALESCE(ea.total_escolas, 0) > 0
        THEN ROUND(COALESCE(ea.total_matriculas, 0)::NUMERIC / ea.total_escolas, 0)
        ELSE NULL
    END AS alunos_por_escola,

    CASE
        WHEN COALESCE(ea.total_docentes, 0) > 0
        THEN ROUND(COALESCE(ea.docentes_superior, 0)::NUMERIC / ea.total_docentes * 100, 2)
        ELSE NULL
    END AS perc_docentes_superior,

    CASE
        WHEN COALESCE(ea.total_docentes, 0) > 0
        THEN ROUND(COALESCE(ea.docentes_concursados, 0)::NUMERIC / ea.total_docentes * 100, 2)
        ELSE NULL
    END AS perc_docentes_concursados

FROM rede_base rb
LEFT JOIN escolas_agregado ea
  ON ea.co_municipio = rb.co_municipio AND ea.tp_dependencia = rb.tp_dependencia
LEFT JOIN ideb_pivot ip
  ON ip.co_municipio = rb.co_municipio AND ip.tp_dependencia = rb.tp_dependencia;

-- Índices e comentários
CREATE UNIQUE INDEX idx_mv_rede_escolas_municipio_rede ON analytics.mv_rede_escolas (co_municipio, codigo_rede);
CREATE INDEX idx_mv_rede_escolas_rede ON analytics.mv_rede_escolas (rede);
CREATE INDEX idx_mv_rede_escolas_uf ON analytics.mv_rede_escolas (sg_uf);

COMMENT ON MATERIALIZED VIEW analytics.mv_rede_escolas IS 'VIEW MATERIALIZADA - Rede de escolas por município e tipo de administração (federal, estadual, municipal, privada). Agrega matrículas e professores do Censo Escolar 2025, etapas oferecidas e desempenho IDEB/SAEB (último ano por etapa).';
COMMENT ON COLUMN analytics.mv_rede_escolas.co_municipio IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN analytics.mv_rede_escolas.no_municipio IS 'Nome do municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.sg_uf IS 'Sigla da UF.';
COMMENT ON COLUMN analytics.mv_rede_escolas.no_regiao IS 'Regiao do pais.';
COMMENT ON COLUMN analytics.mv_rede_escolas.codigo_rede IS 'Codigo da dependencia administrativa (1 federal, 2 estadual, 3 municipal, 4 privada).';
COMMENT ON COLUMN analytics.mv_rede_escolas.rede IS 'Tipo de administração da rede (federal, estadual, municipal, privada), rótulo do dicionário do Censo';
COMMENT ON COLUMN analytics.mv_rede_escolas.total_escolas IS 'Total de escolas da rede no município';
COMMENT ON COLUMN analytics.mv_rede_escolas.total_etapas IS 'Soma de etapas/modalidades oferecidas pelas escolas da rede no município (nro_etapas)';
COMMENT ON COLUMN analytics.mv_rede_escolas.media_etapas IS 'Média de etapas/modalidades oferecidas por escola da rede no município';
COMMENT ON COLUMN analytics.mv_rede_escolas.total_matriculas IS 'Total de matrículas na educação básica (Censo 2025)';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_infantil IS 'Matriculas na educacao infantil da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental IS 'Matriculas no ensino fundamental (total) da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_ai IS 'Matriculas no fundamental - anos iniciais da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_af IS 'Matriculas no fundamental - anos finais da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_medio IS 'Matriculas no ensino medio da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_profissional IS 'Matriculas na educacao profissional da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_eja IS 'Matriculas na EJA da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_especial IS 'Matriculas na educacao especial da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_integral IS 'Matriculas em tempo integral da rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.total_docentes IS 'Total de docentes na educação básica (Censo 2025)';
COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_superior IS 'Docentes com ensino superior na rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_concursados IS 'Docentes com vinculo efetivo/concursado na rede no municipio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_fund_i IS 'IDEB da rede nos anos iniciais do fundamental.';
COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_fund_ii IS 'IDEB da rede nos anos finais do fundamental (média do último ano disponível)';
COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_medio IS 'IDEB da rede no ensino medio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_fund_ii IS 'Proficiencia media (Matematica+Portugues) nos anos finais.';
COMMENT ON COLUMN analytics.mv_rede_escolas.nota_matematica_fund_ii IS 'Proficiencia media em Matematica nos anos finais.';
COMMENT ON COLUMN analytics.mv_rede_escolas.nota_portugues_fund_ii IS 'Proficiencia media em Lingua Portuguesa nos anos finais.';
COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_medio IS 'Proficiencia media (Matematica+Portugues) no ensino medio.';
COMMENT ON COLUMN analytics.mv_rede_escolas.ano_ideb IS 'Ano do IDEB/SAEB usado como referencia (ultimo disponivel).';
COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_docente IS 'Razao matriculas/docentes; carga de alunos por professor.';
COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_escola IS 'Razao matriculas/escolas; porte medio das escolas da rede.';
COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_superior IS 'Percentual de docentes com ensino superior.';
COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_concursados IS 'Percentual de docentes efetivos/concursados.';

-- Função para atualizar a view materializada
CREATE OR REPLACE FUNCTION analytics.refresh_rede_escolas()
RETURNS TEXT AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    start_time := clock_timestamp();
    REFRESH MATERIALIZED VIEW CONCURRENTLY analytics.mv_rede_escolas;
    end_time := clock_timestamp();
    RETURN format('View materializada atualizada em %s segundos',
                  EXTRACT(EPOCH FROM (end_time - start_time))::NUMERIC(10,2));
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION analytics.refresh_rede_escolas() IS 'Atualiza a view materializada mv_rede_escolas com dados mais recentes. Retorna o tempo de execução.';

COMMIT;
