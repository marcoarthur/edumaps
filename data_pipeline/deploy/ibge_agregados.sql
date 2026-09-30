-- Deploy edumaps:ibge_agregados to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0
-- requires: extensions

BEGIN;

-- =================================================================
-- IBGE AGREGADOS SIDRA - FORMATO LONGO
-- Extensão da tabela dados_ibge (que tem PIB wide)
-- Formato longo: codigo_ibge, ano, tabela_id, variavel, classificacao, valor
-- =================================================================

CREATE TABLE IF NOT EXISTS clean.ibge_agregados (
    codigo_ibge   TEXT NOT NULL,     -- 7 dígitos
    ano           SMALLINT NOT NULL, -- ano de referência
    tabela_id     TEXT NOT NULL,     -- ex: '1393' (PIB), '6579' (População), '1093' (IDHM)
    variavel      TEXT NOT NULL,     -- ex: '93', '214', '216'
    classificacao TEXT,              -- classificação (opcional, ex: setor econômico)
    valor         NUMERIC,           -- valor do indicador
    unidade       TEXT,              -- unidade de medida
    data_acessada TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT ibge_agregados_pk PRIMARY KEY (codigo_ibge, ano, tabela_id, variavel, classificacao)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_ibge_agregados_codigo ON clean.ibge_agregados (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_ibge_agregados_ano ON clean.ibge_agregados (ano);
CREATE INDEX IF NOT EXISTS idx_ibge_agregados_tabela ON clean.ibge_agregados (tabela_id);
CREATE INDEX IF NOT EXISTS idx_ibge_agregados_codigo_ano ON clean.ibge_agregados (codigo_ibge, ano);

-- Comentários
COMMENT ON TABLE clean.ibge_agregados IS 'Agregados IBGE SIDRA em formato longo (tabela_id + variavel + classificacao). Extende dados_ibge (PIB wide) para qualquer agregado SIDRA.';
COMMENT ON COLUMN clean.ibge_agregados.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.ibge_agregados.ano IS 'Ano de referência do agregado';
COMMENT ON COLUMN clean.ibge_agregados.tabela_id IS 'ID da tabela SIDRA (ex: 1393=PIB, 6579=População, 1093=IDHM, 5938=PIB per capita)';
COMMENT ON COLUMN clean.ibge_agregados.variavel IS 'Código da variável dentro da tabela SIDRA';
COMMENT ON COLUMN clean.ibge_agregados.classificacao IS 'Classificação/categoria (ex: setor econômico, faixa de IDHM)';
COMMENT ON COLUMN clean.ibge_agregados.valor IS 'Valor numérico do indicador';
COMMENT ON COLUMN clean.ibge_agregados.unidade IS 'Unidade de medida (ex: reais, habitantes, índice 0-1)';
COMMENT ON COLUMN clean.ibge_agregados.data_acessada IS 'Timestamp de quando o dado foi coletado do SIDRA v3';

-- View para facilitar consultas comuns (PIB, População, IDHM)
CREATE OR REPLACE VIEW clean.v_ibge_municipio_ano AS
SELECT
    a.codigo_ibge,
    m.nome_municipio,
    m.sigla_uf,
    a.ano,
    MAX(CASE WHEN a.tabela_id = '1393' AND a.variavel = '93' THEN a.valor END) AS pib_total,
    MAX(CASE WHEN a.tabela_id = '1393' AND a.variavel = '214' THEN a.valor END) AS vab_agro,
    MAX(CASE WHEN a.tabela_id = '1393' AND a.variavel = '215' THEN a.valor END) AS vab_industria,
    MAX(CASE WHEN a.tabela_id = '1393' AND a.variavel = '216' THEN a.valor END) AS vab_servicos,
    MAX(CASE WHEN a.tabela_id = '1393' AND a.variavel = '217' THEN a.valor END) AS vab_adm_publica,
    MAX(CASE WHEN a.tabela_id = '6579' AND a.variavel = '93' THEN a.valor END) AS populacao,
    MAX(CASE WHEN a.tabela_id = '1093' AND a.variavel = '1000' THEN a.valor END) AS idhm,
    MAX(CASE WHEN a.tabela_id = '5938' AND a.variavel = '93' THEN a.valor END) AS pib_per_capita
FROM clean.ibge_agregados a
JOIN clean.malha_municipio m ON m.codigo_ibge = a.codigo_ibge
GROUP BY a.codigo_ibge, m.nome_municipio, m.sigla_uf, a.ano;

COMMENT ON VIEW clean.v_ibge_municipio_ano IS 'View pivô dos principais agregados IBGE por município/ano (PIB, População, IDHM, PIB per capita).';

-- Registro de metadados da importação
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.ibge_agregados'::text,
       'SIDRA v3 via servicodados.ibge.gov.br'::text,
       'https://servicodados.ibge.gov.br/api/v1/sidra/v3/'::text,
       'Domínio público (IBGE)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: ibge_agregados (SIDRA v3 formato longo)'
FROM clean.ibge_agregados;

COMMIT;