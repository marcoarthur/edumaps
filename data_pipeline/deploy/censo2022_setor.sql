-- Deploy edumaps:censo2022_setor to pg
-- requires: malha_setor_censitario
-- requires: ibge_agregados
-- requires: import_metadata_fase0
-- requires: extensions

BEGIN;

-- =================================================================
-- CENSO 2022 POR SETOR CENSITÁRIO
-- 316.574 setores, ~3.000 variáveis
-- Fonte: IBGE - Censo Demográfico 2022 (arquivos CSV/GPKG)
-- ATENÇÃO: Vazio ≠ zero (supressão de célula pequena é estado distinto)
-- =================================================================

CREATE TABLE IF NOT EXISTS clean.censo2022_setor (
    codigo_setor     TEXT NOT NULL,      -- 15 dígitos (7 município + 8 setor)
    codigo_ibge      TEXT NOT NULL,      -- 7 dígitos (município)
    nome_municipio   TEXT,
    sigla_uf         CHAR(2),
    situacao_setor   TEXT,               -- urbano/rural

    -- População total
    pop_total        INTEGER,
    pop_homens       INTEGER,
    pop_mulheres     INTEGER,

    -- Domicílios
    dom_total        INTEGER,
    dom_particular   INTEGER,
    dom_coletivo     INTEGER,

    -- Idade (faixas principais)
    idade_0_4        INTEGER,
    idade_5_9        INTEGER,
    idade_10_14      INTEGER,
    idade_15_19      INTEGER,
    idade_20_29      INTEGER,
    idade_30_39      INTEGER,
    idade_40_49      INTEGER,
    idade_50_59      INTEGER,
    idade_60_69      INTEGER,
    idade_70_mais    INTEGER,

    -- Escolaridade (25+ anos)
    esc_sem_instrucao     INTEGER,
    esc_fund_incomp       INTEGER,
    esc_fund_comp         INTEGER,
    esc_med_incomp        INTEGER,
    esc_med_comp          INTEGER,
    esc_sup_incomp        INTEGER,
    esc_sup_comp          INTEGER,

    -- Cor/raça
    cor_branca      INTEGER,
    cor_preta       INTEGER,
    cor_amarela     INTEGER,
    cor_parda       INTEGER,
    cor_indigena    INTEGER,
    cor_sem_decl    INTEGER,

    -- Rendimento
    rend_media        NUMERIC,
    rend_per_capita   NUMERIC,

    -- Supressão de célula pequena (vazio ≠ zero)
    -- Se supressao = true, os valores acima são nulos por motivo de sigilo estatístico
    supressao_celula_pequena BOOLEAN DEFAULT FALSE,

    -- Metadados
    data_acessada TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT censo2022_setor_pk PRIMARY KEY (codigo_setor)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_censo2022_setor_codigo_ibge ON clean.censo2022_setor (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_censo2022_setor_uf ON clean.censo2022_setor (sigla_uf);
CREATE INDEX IF NOT EXISTS idx_censo2022_setor_supressao ON clean.censo2022_setor (supressao_celula_pequena);

-- FK para malha_setor_censitario
ALTER TABLE clean.censo2022_setor
  ADD CONSTRAINT fk_censo2022_setor_malha
  FOREIGN KEY (codigo_setor) REFERENCES clean.malha_setor_censitario(codigo_setor)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';
COMMENT ON COLUMN clean.censo2022_setor.codigo_setor IS 'Código do setor censitário (15 dígitos) - PK e FK para malha_setor_censitario';
COMMENT ON COLUMN clean.censo2022_setor.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.censo2022_setor.supressao_celula_pequena IS 'TRUE = valor suprimido por sigilo estatístico (célula pequena), NÃO é zero. FALSE = valor real (pode ser zero real).';

COMMENT ON COLUMN clean.censo2022_setor.pop_total IS 'População total residente no setor';
COMMENT ON COLUMN clean.censo2022_setor.dom_total IS 'Total de domicílios particulares permanentes';
COMMENT ON COLUMN clean.censo2022_setor.rend_per_capita IS 'Rendimento médio per capita (reais)';
COMMENT ON COLUMN clean.censo2022_setor.esc_sem_instrucao IS 'Pessoas 25+ anos sem instrução';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_incomp IS 'Pessoas 25+ anos com fundamental incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_comp IS 'Pessoas 25+ anos com fundamental completo';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_incomp IS 'Pessoas 25+ anos com médio incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_comp IS 'Pessoas 25+ anos com médio completo';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_incomp IS 'Pessoas 25+ anos com superior incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_comp IS 'Pessoas 25+ anos com superior completo';
COMMENT ON COLUMN clean.censo2022_setor.cor_branca IS 'Cor/raça branca';
COMMENT ON COLUMN clean.censo2022_setor.cor_preta IS 'Cor/raça preta';
COMMENT ON COLUMN clean.censo2022_setor.cor_amarela IS 'Cor/raça amarela';
COMMENT ON COLUMN clean.censo2022_setor.cor_parda IS 'Cor/raça parda';
COMMENT ON COLUMN clean.censo2022_setor.cor_indigena IS 'Cor/raça indígena';
COMMENT ON COLUMN clean.censo2022_setor.cor_sem_decl IS 'Cor/raça sem declaração';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.censo2022_setor'::text,
       'Censo 2022 setor censitário (CSV/GPKG IBGE)'::text,
       'https://geoftp.ibge.gov.br/recenseamento_2022/'::text,
       'Domínio público (IBGE)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: censo2022_setor. Vazio ≠ zero - ver supressao_celula_pequena.'
FROM clean.censo2022_setor;

COMMIT;