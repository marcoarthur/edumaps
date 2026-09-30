-- Deploy edumaps:siconfi_despesa to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- SICONFI / TESOUROR - DESPESAS MUNICIPAIS
-- Fonte: tesouror.transparencia.gov.br/api/v1/despesas
-- Chave: codigo_ibge + exercicio + funcao + subfuncao + classificacao
-- =================================================================

DROP TABLE IF EXISTS clean.siconfi_despesa;
CREATE TABLE clean.siconfi_despesa (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    exercicio         SMALLINT NOT NULL,  -- ano do exercício
    funcao            SMALLINT NOT NULL,  -- código da função (ex.: 12 = educação)
    subfuncao         SMALLINT NOT NULL,  -- código da subfunção (ex.: 361 = ensino fundamental)
    coluna_despesa    TEXT NOT NULL,      -- código da coluna SICONFI
    descricao_despesa TEXT,               -- descrição legível
    valor_empenhado   NUMERIC,            -- valor empenhado
    valor_liquidado   NUMERIC,            -- valor liquidado
    valor_pago        NUMERIC,            -- valor pago
    -- Classificação: 'realizada' ou 'estimativa'
    classificacao     TEXT NOT NULL DEFAULT 'realizada',
    -- Metadados
    dt_snapshot       DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_siconfi_despesa PRIMARY KEY (codigo_ibge, exercicio, funcao, subfuncao, coluna_despesa, classificacao, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_codigo_ibge ON clean.siconfi_despesa (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_exercicio ON clean.siconfi_despesa (exercicio);
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_funcao ON clean.siconfi_despesa (funcao);
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_subfuncao ON clean.siconfi_despesa (subfuncao);
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_classificacao ON clean.siconfi_despesa (classificacao);
CREATE INDEX IF NOT EXISTS idx_siconfi_despesa_dt_snapshot ON clean.siconfi_despesa (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.siconfi_despesa
  ADD CONSTRAINT fk_siconfi_despesa_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.siconfi_despesa IS 'Despesas municipais SICONFI/Tesouro Nacional. Chave: codigo_ibge + exercicio + funcao + subfuncao + coluna_despesa + classificacao + dt_snapshot. FUNÇÃO 12 = Educação. SUBFUNÇÃO 361 = Ensino Fundamental, 362 = Ensino Médio, 363 = Educação Infantil, 364 = Educação de Jovens e Adultos, 365 = Educação Especial. SEMPRE filtrar classificacao=realizada.';
COMMENT ON COLUMN clean.siconfi_despesa.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.siconfi_despesa.exercicio IS 'Ano do exercício financeiro';
COMMENT ON COLUMN clean.siconfi_despesa.funcao IS 'Código da função (12 = Educação)';
COMMENT ON COLUMN clean.siconfi_despesa.subfuncao IS 'Código da subfunção (ex.: 361=Ensino Fundamental)';
COMMENT ON COLUMN clean.siconfi_despesa.coluna_despesa IS 'Código da coluna SICONFI';
COMMENT ON COLUMN clean.siconfi_despesa.descricao_despesa IS 'Descrição legível da despesa';
COMMENT ON COLUMN clean.siconfi_despesa.valor_empenhado IS 'Valor empenhado';
COMMENT ON COLUMN clean.siconfi_despesa.valor_liquidado IS 'Valor liquidado';
COMMENT ON COLUMN clean.siconfi_despesa.valor_pago IS 'Valor pago';
COMMENT ON COLUMN clean.siconfi_despesa.classificacao IS 'realizada (execução) ou estimativa (orçamento) — NÃO misturar';
COMMENT ON COLUMN clean.siconfi_despesa.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.siconfi_despesa'::text,
       'API Tesouro Nacional SICONFI despesas'::text,
       'https://tesouror.transparencia.gov.br/api/v1/despesas'::text,
       'Domínio público (Tesouro Nacional)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: siconfi_despesa. SEMPRE filtrar classificacao=realizada.'
FROM clean.siconfi_despesa;

COMMIT;