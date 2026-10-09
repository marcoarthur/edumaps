-- Deploy edumaps:siconfi_despesa_dca to pg
-- requires: siconfi_despesa

BEGIN;

-- =================================================================
-- FASE 2 (#193): clean.siconfi_despesa passa a reflectir a fonte real
-- da despesa por função: o DCA-Anexo I-E do SICONFI (DCASP anual), e
-- não a API "tesouror" presumida no schema original.
--
-- O payload real (medido 2026-10-08 em SP 2024/2025) não tem
-- `coluna_despesa`: cada linha é uma função com os três valores
-- (empenhado/liquidado/pago) juntos. A coluna textual era uma chave
-- inventada para uma fonte que esta API não serve; a PK passa a ser a
-- unidade natural do dado.
--
-- Granularidade: uma linha por FUNÇÃO (subfuncao = 0), porque o payload
-- não reconcilia pai vs. soma dos filhos (medido no SP 2024: função 12
-- = 23,29 bi vs. 21,42 bi da soma das subfunções — diff 8%). Guardar só
-- os filhos distorceria o total oficial da função 12 que a view usa.
-- =================================================================

ALTER TABLE clean.siconfi_despesa DROP COLUMN coluna_despesa;

-- DROP COLUMN derruba a PK antiga (depende da coluna); recria com o
-- MESMO nome para o verify da change original continuar válido (ele só
-- checa a existência de `pk_siconfi_despesa`).
ALTER TABLE clean.siconfi_despesa
  ADD CONSTRAINT pk_siconfi_despesa
    PRIMARY KEY (codigo_ibge, exercicio, funcao, subfuncao, classificacao, dt_snapshot);

-- Comentários corrigidos para a verdade da fonte
COMMENT ON TABLE clean.siconfi_despesa IS 'Despesas municipais por função (SICONFI DCA-Anexo I-E, DCASP anual). Chave: codigo_ibge + exercicio + funcao + classificacao + dt_snapshot. FUNÇÃO 12 = Educação. SEMPRE filtrar classificacao=realizada.';
COMMENT ON COLUMN clean.siconfi_despesa.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.siconfi_despesa.exercicio IS 'Ano do exercício financeiro (DCA fechado)';
COMMENT ON COLUMN clean.siconfi_despesa.funcao IS 'Código da função orçamentária (12 = Educação)';
COMMENT ON COLUMN clean.siconfi_despesa.subfuncao IS 'Código da subfunção; 0 = linha de função (total oficial do demonstrativo). Granularidade por subfunção descartada: no payload pai ≠ Σ filhos (medido: diff 8% no SP 2024), logo os filhos não reconciliam com o total da função.';
COMMENT ON COLUMN clean.siconfi_despesa.descricao_despesa IS 'Nome da função (ex.: Educação)';
COMMENT ON COLUMN clean.siconfi_despesa.valor_empenhado IS 'Despesas Empenhadas (coluna do DCA-Anexo I-E)';
COMMENT ON COLUMN clean.siconfi_despesa.valor_liquidado IS 'Despesas Liquidadas (coluna do DCA-Anexo I-E)';
COMMENT ON COLUMN clean.siconfi_despesa.valor_pago IS 'Despesas Pagas (coluna do DCA-Anexo I-E)';
COMMENT ON COLUMN clean.siconfi_despesa.classificacao IS 'realizada (execução) ou estimativa (orçamento) — NÃO misturar';
COMMENT ON COLUMN clean.siconfi_despesa.dt_snapshot IS 'Data do snapshot (chave de versionamento)';

COMMIT;