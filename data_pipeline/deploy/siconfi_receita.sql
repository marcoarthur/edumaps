-- Deploy edumaps:siconfi_receita to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- SICONFI / TESOUROR - RECEITAS MUNICIPAIS
-- Fonte: tesouror.transparencia.gov.br/api/v1/receitas
-- Chave: codigo_ibge (7 dígitos) + exercicio + tipo_receita
-- =================================================================

DROP TABLE IF EXISTS clean.siconfi_receita;
CREATE TABLE clean.siconfi_receita (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    exercicio         SMALLINT NOT NULL,  -- ano do exercício
    tipo_receita      TEXT NOT NULL,      -- 'propria', 'transferencia', 'fundeb', 'outros'
    coluna_receita    TEXT NOT NULL,      -- código da coluna SICONFI (ex.: '1.1.1.1.01')
    descricao_receita TEXT,               -- descrição legível
    valor             NUMERIC NOT NULL,   -- valor em reais
    -- Classificação: 'realizada' ou 'estimativa'
    classificacao     TEXT NOT NULL DEFAULT 'realizada',
    -- Metadados
    dt_snapshot       DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_siconfi_receita PRIMARY KEY (codigo_ibge, exercicio, tipo_receita, coluna_receita, classificacao, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_siconfi_receita_codigo_ibge ON clean.siconfi_receita (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_siconfi_receita_exercicio ON clean.siconfi_receita (exercicio);
CREATE INDEX IF NOT EXISTS idx_siconfi_receita_tipo ON clean.siconfi_receita (tipo_receita);
CREATE INDEX IF NOT EXISTS idx_siconfi_receita_classificacao ON clean.siconfi_receita (classificacao);
CREATE INDEX IF NOT EXISTS idx_siconfi_receita_dt_snapshot ON clean.siconfi_receita (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.siconfi_receita
  ADD CONSTRAINT fk_siconfi_receita_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.siconfi_receita IS 'Receitas municipais SICONFI/Tesouro Nacional. Chave: codigo_ibge + exercicio + tipo_receita + coluna_receita + classificacao + dt_snapshot. SEMPRE filtrar por classificacao=''realizada'' para indicadores; ''estimativa'' é projeção orçamentária.';
COMMENT ON COLUMN clean.siconfi_receita.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.siconfi_receita.exercicio IS 'Ano do exercício financeiro';
COMMENT ON COLUMN clean.siconfi_receita.tipo_receita IS 'Tipo: propria, transferencia, fundeb, outros';
COMMENT ON COLUMN clean.siconfi_receita.coluna_receita IS 'Código da coluna SICONFI (ex.: 1.1.1.1.01)';
COMMENT ON COLUMN clean.siconfi_receita.descricao_receita IS 'Descrição legível da receita';
COMMENT ON COLUMN clean.siconfi_receita.valor IS 'Valor em reais';
COMMENT ON COLUMN clean.siconfi_receita.classificacao IS 'realizada (execução) ou estimativa (orçamento) — NÃO misturar';
COMMENT ON COLUMN clean.siconfi_receita.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.siconfi_receita'::text,
       'API Tesouro Nacional SICONFI receitas'::text,
       'https://tesouror.transparencia.gov.br/api/v1/receitas'::text,
       'Domínio público (Tesouro Nacional)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: siconfi_receita. SEMPRE filtrar classificacao=realizada.'
FROM clean.siconfi_receita;

COMMIT;