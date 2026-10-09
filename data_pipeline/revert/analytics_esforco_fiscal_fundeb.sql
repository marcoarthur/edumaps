-- Revert edumaps:analytics_esforco_fiscal_fundeb from pg

BEGIN;

-- Restaura o corpo original (denominador com todo o 'realizada', sem o
-- ajuste de duplo-conto do FUNDEB).
CREATE OR REPLACE VIEW analytics.esforco_fiscal_educacao AS
WITH
    -- Receitas municipais: FUNDEB + transferências educação + receita própria
    receitas AS (
        SELECT
            r.codigo_ibge,
            r.exercicio,
            SUM(CASE WHEN r.tipo_receita = 'fundeb' THEN r.valor ELSE 0 END) AS fundeb_receita,
            SUM(CASE WHEN r.tipo_receita = 'transferencia' THEN r.valor ELSE 0 END) AS transferencias_educ_receita,
            SUM(CASE WHEN r.tipo_receita = 'propria' THEN r.valor ELSE 0 END) AS receita_propria,
            SUM(r.valor) AS receita_total,
            r.dt_snapshot
        FROM clean.siconfi_receita r
        WHERE r.classificacao = 'realizada'
        GROUP BY r.codigo_ibge, r.exercicio, r.dt_snapshot
    ),
    -- Despesas com educação (função 12)
    despesas_educ AS (
        SELECT
            d.codigo_ibge,
            d.exercicio,
            SUM(d.valor_pago) AS despesa_educ_paga,
            SUM(d.valor_empenhado) AS despesa_educ_empenhada,
            SUM(d.valor_liquidado) AS despesa_educ_liquidada,
            d.dt_snapshot
        FROM clean.siconfi_despesa d
        WHERE d.classificacao = 'realizada'
          AND d.funcao = 12  -- Educação
        GROUP BY d.codigo_ibge, d.exercicio, d.dt_snapshot
    ),
    -- Transferências CGU (FUNDEB, PNATE, etc.)
    transferencias AS (
        SELECT
            t.codigo_ibge,
            EXTRACT(YEAR FROM t.data_inicio)::SMALLINT AS exercicio,
            SUM(CASE WHEN t.programa = 'FUNDEB' THEN t.valor_transferido ELSE 0 END) AS fundeb_transferido,
            SUM(CASE WHEN t.programa = 'PNATE' THEN t.valor_transferido ELSE 0 END) AS pnate_transferido,
            SUM(CASE WHEN t.programa = 'PROINFANCIA' THEN t.valor_transferido ELSE 0 END) AS proinfancia_transferido,
            SUM(CASE WHEN t.programa = 'PDDE' THEN t.valor_transferido ELSE 0 END) AS pdde_transferido,
            SUM(t.valor_transferido) AS total_transferido,
            t.dt_snapshot
        FROM clean.transferencia_educ t
        GROUP BY t.codigo_ibge, EXTRACT(YEAR FROM t.data_inicio)::SMALLINT, t.dt_snapshot
    ),
    -- Matrículas totais (Censo Escolar mais recente - tabela censo_matriculas)
    matriculas AS (
        SELECT
            e.co_municipio AS codigo_ibge,
            m.nu_ano_censo AS exercicio,
            SUM(m.qt_mat_bas) AS total_matriculas
        FROM clean.censo_matriculas m
        JOIN clean.censo_escolas e ON e.co_entidade = m.co_entidade AND e.nu_ano_censo = m.nu_ano_censo
        WHERE e.tp_situacao_funcionamento = 1
          AND m.nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_matriculas)
        GROUP BY e.co_municipio, m.nu_ano_censo
    ),
    -- População municipal (denominador para per capita)
    populacao AS (
        SELECT
            m.codigo_ibge,
            p.populacao_estimada
        FROM clean.malha_municipio m
        LEFT JOIN clean.populacao_municipal p ON p.codigo_ibge = m.codigo_ibge
        WHERE p.populacao_estimada IS NOT NULL
    )
SELECT
    r.codigo_ibge,
    m.nome_municipio,
    r.exercicio,
    -- Receitas
    r.fundeb_receita,
    r.transferencias_educ_receita,
    r.receita_propria,
    r.receita_total,
    -- Despesas
    d.despesa_educ_paga,
    d.despesa_educ_empenhada,
    d.despesa_educ_liquidada,
    -- Transferências CGU
    t.fundeb_transferido,
    t.pnate_transferido,
    t.proinfancia_transferido,
    t.pdde_transferido,
    t.total_transferido,
    -- Matrículas
    ma.total_matriculas,
    -- População
    p.populacao_estimada,
    -- Indicadores derivados
    CASE WHEN ma.total_matriculas > 0 THEN round(r.fundeb_receita::numeric / ma.total_matriculas, 2) END AS fundeb_por_aluno,
    CASE WHEN ma.total_matriculas > 0 THEN round(d.despesa_educ_paga::numeric / ma.total_matriculas, 2) END AS despesa_educ_por_aluno,
    CASE WHEN r.receita_total > 0 THEN round(d.despesa_educ_paga::numeric / r.receita_total * 100, 2) END AS pct_receita_em_educ,
    CASE WHEN p.populacao_estimada > 0 THEN round(r.receita_total::numeric / p.populacao_estimada, 2) END AS receita_per_capita,
    CASE WHEN r.receita_total > 0 THEN round(r.receita_propria::numeric / r.receita_total * 100, 2) END AS autonomia_fiscal_pct,
    CASE WHEN r.receita_total > 0 THEN round(r.fundeb_receita::numeric / r.receita_total * 100, 2) END AS dependencia_fundeb_pct,
    CASE WHEN r.receita_total > 0 THEN round((r.transferencias_educ_receita + r.fundeb_receita)::numeric / r.receita_total * 100, 2) END AS dependencia_federal_pct,
    -- Metadados
    r.dt_snapshot AS receita_snapshot,
    d.dt_snapshot AS despesa_snapshot,
    t.dt_snapshot AS transferencia_snapshot,
    CURRENT_DATE AS computed_at
FROM receitas r
LEFT JOIN despesas_educ d ON d.codigo_ibge = r.codigo_ibge AND d.exercicio = r.exercicio
LEFT JOIN transferencias t ON t.codigo_ibge = r.codigo_ibge AND t.exercicio = r.exercicio
LEFT JOIN matriculas ma ON ma.codigo_ibge::text = r.codigo_ibge AND ma.exercicio = r.exercicio
LEFT JOIN populacao p ON p.codigo_ibge = r.codigo_ibge
JOIN clean.malha_municipio m ON m.codigo_ibge = r.codigo_ibge
WHERE r.receita_total > 0;

COMMENT ON VIEW analytics.esforco_fiscal_educacao IS 'Esforço fiscal municipal em educação. Combina SICONFI (receitas/despesas realizadas) + CGU transferências + Censo Escolar (matrículas). SEMPRE filtrar classificacao=realizada. Indicadores: FUNDEB/aluno, despesa/aluno, % receita em educação, autonomia fiscal, dependência FUNDEB/federal.';

COMMIT;