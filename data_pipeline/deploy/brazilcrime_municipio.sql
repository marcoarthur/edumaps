-- Deploy edumaps:brazilcrime_municipio to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- BRAZILCRIME - CRIMINALIDADE AGREGADA POR MUNICÍPIO/ANO
-- Fonte: pacote R BrazilCrime (CRAN) - dados oficiais SSP/IBGE
-- AGREGAÇÃO OBRIGATÓRIA: por município/ano, supressão count < 5
-- NUNCA expor por escola — nem agregada
-- =================================================================

DROP TABLE IF EXISTS clean.brazilcrime_municipio;
CREATE TABLE clean.brazilcrime_municipio (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    ano               SMALLINT NOT NULL,  -- ano de referência
    -- Tipos de crime (base SSP/IBGE)
    homicidio_doloso       INTEGER,       -- homicídio doloso
    homicidio_culposo      INTEGER,       -- homicídio culposo (trânsito)
    latrocinio             INTEGER,       -- roubo seguido de morte
    roubo_veiculo          INTEGER,       -- roubo de veículo
    roubo_carga            INTEGER,       -- roubo de carga
    roubo_outros           INTEGER,       -- outros roubos
    furto_veiculo          INTEGER,       -- furto de veículo
    furto_outros           INTEGER,       -- outros furtos
    estelionato            INTEGER,       -- estelionato
    ameaca                 INTEGER,       -- ameaça
    lesao_corporal         INTEGER,       -- lesão corporal
    violacao_domicilio     INTEGER,       -- violação de domicílio
    -- Supressão de célula pequena (count < 5)
    supressao_celula_pequena BOOLEAN DEFAULT FALSE,  -- TRUE = valor suprimido por sigilo estatístico
    -- Metadados
    dt_snapshot       DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_brazilcrime_municipio PRIMARY KEY (codigo_ibge, ano, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_brazilcrime_codigo_ibge ON clean.brazilcrime_municipio (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_brazilcrime_ano ON clean.brazilcrime_municipio (ano);
CREATE INDEX IF NOT EXISTS idx_brazilcrime_dt_snapshot ON clean.brazilcrime_municipio (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.brazilcrime_municipio
  ADD CONSTRAINT fk_brazilcrime_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.brazilcrime_municipio IS 'Criminalidade agregada por município/ano (BrazilCrime/CRAN). AGREGAÇÃO OBRIGATÓRIA: por município, supressão count < 5. NUNCA expor por escola. Supressão de célula pequena (count < 5) indicada em supressao_celula_pequena.';
COMMENT ON COLUMN clean.brazilcrime_municipio.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.brazilcrime_municipio.ano IS 'Ano de referência dos dados';
COMMENT ON COLUMN clean.brazilcrime_municipio.homicidio_doloso IS 'Homicídio doloso';
COMMENT ON COLUMN clean.brazilcrime_municipio.homicidio_culposo IS 'Homicídio culposo (trânsito)';
COMMENT ON COLUMN clean.brazilcrime_municipio.latrocinio IS 'Roubo seguido de morte (latrocínio)';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_veiculo IS 'Roubo de veículo';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_carga IS 'Roubo de carga';
COMMENT ON COLUMN clean.brazilcrime_municipio.roubo_outros IS 'Outros roubos';
COMMENT ON COLUMN clean.brazilcrime_municipio.furto_veiculo IS 'Furto de veículo';
COMMENT ON COLUMN clean.brazilcrime_municipio.furto_outros IS 'Outros furtos';
COMMENT ON COLUMN clean.brazilcrime_municipio.estelionato IS 'Estelionato';
COMMENT ON COLUMN clean.brazilcrime_municipio.ameaca IS 'Ameaça';
COMMENT ON COLUMN clean.brazilcrime_municipio.lesao_corporal IS 'Lesão corporal';
COMMENT ON COLUMN clean.brazilcrime_municipio.violacao_domicilio IS 'Violação de domicílio';
COMMENT ON COLUMN clean.brazilcrime_municipio.supressao_celula_pequena IS 'TRUE = valor suprimido por sigilo estatístico (count < 5), NÃO é zero';
COMMENT ON COLUMN clean.brazilcrime_municipio.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.brazilcrime_municipio'::text,
       'Pacote R BrazilCrime (CRAN)'::text,
       'https://cran.r-project.org/package=BrazilCrime'::text,
       'GPL-3 (CRAN)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: brazilcrime_municipio. AGREGAÇÃO OBRIGATÓRIA: por município, supressão count < 5. NUNCA expor por escola.'
FROM clean.brazilcrime_municipio;

COMMIT;