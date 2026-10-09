-- Deploy edumaps:analytics_esforco_fiscal_fundeb to pg
-- requires: analytics_esforco_fiscal

BEGIN;

-- =================================================================
-- FASE 2 (#193): receita FUNDEB real no esforço fiscal.
--
-- A fase 1 (RREO Anexo 01) só conhece o agregado de transferências dos
-- estados, que JÁ contém o FUNDEB. A fase 2 adiciona linhas
-- 'fundeb' (DCA-Anexo I-C: 1.7.5.1 = FUNDEB e 1.7.1.5 = complementação
-- da União ao FUNDEB) como detalhamento. Sem o ajuste abaixo, o FUNDEB
-- entraria DUAS vezes em receita_total (no agregado e na linha nova),
-- inflando o denominador de autonomia/dependência.
--
-- Mudança em relação à fase 1:
--  * receita_total passa a excluir tipo_receita='fundeb' (o FUNDEB
--    permanece contido no agregado 'transferencia');
--  * receitas e despesas agora agregam por (município, exercício)
--    tomando o ÚLTIMO snapshot por chave (DISTINCT ON), em vez de
--    agrupar por dt_snapshot: como RREO e DCA entram em datas de
--    snapshot diferentes, agrupar por snapshot separaria as fontes e o
--    FUNDEB desapareceria da linha (medido no SP 2025: fundeb_receita=0).
--
-- Mesmas colunas e indicadores — CREATE OR REPLACE sem alterar o
-- contrato da view.
-- =================================================================

CREATE OR REPLACE VIEW analytics.esforco_fiscal_educacao AS
WITH
    -- Receitas municipais: FUNDEB + transferências educação + receita própria.
    -- Último snapshot por (município, exercício, tipo, coluna): a tabela
    -- acumula snapshots de fontes distintas (RREO e DCA) em datas
    -- diferentes; pegar só o grupo de um snapshot perderia uma das fontes.
    receitas AS (
        SELECT
            codigo_ibge,
            exercicio,
            SUM(CASE WHEN tipo_receita = 'fundeb' THEN valor ELSE 0 END)        AS fundeb_receita,
            SUM(CASE WHEN tipo_receita = 'transferencia' THEN valor ELSE 0 END) AS transferencias_educ_receita,
            SUM(CASE WHEN tipo_receita = 'propria' THEN valor ELSE 0 END)       AS receita_propria,
            -- FUNDEB está contido na linha agregada de transferências dos
            -- estados (RREO fase 1); as linhas 'fundeb' do DCA são o
            -- detalhamento — excluir evita o duplo-conto no denominador.
            SUM(CASE WHEN tipo_receita <> 'fundeb' THEN valor ELSE 0 END)       AS receita_total,
            MAX(dt_snapshot) AS dt_snapshot
        FROM (
            SELECT DISTINCT ON (codigo_ibge, exercicio, tipo_receita, coluna_receita)
                   codigo_ibge, exercicio, tipo_receita, coluna_receita,
                   valor, dt_snapshot
              FROM clean.siconfi_receita
             WHERE classificacao = 'realizada'
             ORDER BY codigo_ibge, exercicio, tipo_receita, coluna_receita,
                      dt_snapshot DESC
        ) r
        GROUP BY codigo_ibge, exercicio
    ),
    -- Despesas com educação (função 12). Mesma regra de último snapshot:
    -- despesa DCA (fase 2) e qualquer carga futura convivem por snapshot.
    despesas_educ AS (
        SELECT
            codigo_ibge,
            exercicio,
            SUM(valor_pago)      AS despesa_educ_paga,
            SUM(valor_empenhado) AS despesa_educ_empenhada,
            SUM(valor_liquidado) AS despesa_educ_liquidada,
            MAX(dt_snapshot) AS dt_snapshot
        FROM (
            SELECT DISTINCT ON (codigo_ibge, exercicio, funcao, subfuncao)
                   codigo_ibge, exercicio, funcao, subfuncao,
                   valor_pago, valor_empenhado, valor_liquidado, dt_snapshot
              FROM clean.siconfi_despesa
             WHERE classificacao = 'realizada'
               AND funcao = 12  -- Educação
             ORDER BY codigo_ibge, exercicio, funcao, subfuncao,
                      dt_snapshot DESC
        ) d
        GROUP BY codigo_ibge, exercicio
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

-- Comentários da view
COMMENT ON VIEW analytics.esforco_fiscal_educacao IS 'Esforço fiscal municipal em educação. Combina SICONFI (receitas RREO + despesas DCA, realizadas) + CGU transferências + Censo Escolar (matrículas). SEMPRE filtrar classificacao=realizada. Indicadores: FUNDEB/aluno, despesa/aluno, % receita em educação, autonomia fiscal, dependência FUNDEB/federal. Receita FUNDEB (DCA) é detalhamento do agregado de transferências — excluída do denominador receita_total para não duplicar.';

COMMIT;