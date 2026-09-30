-- Deploy edumaps:sisab_aps to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- DATASUS/SISAB - INDICADORES APS (AGREGADOS MUNICIPAIS/MENSAIS)
-- Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-*
-- =================================================================

DROP TABLE IF EXISTS clean.sisab_aps;
CREATE TABLE clean.sisab_aps (
    codigo_municipio        TEXT NOT NULL,      -- 7 dígitos IBGE
    dt_referencia           DATE NOT NULL,      -- mês de referência (primeiro dia)
    -- Cobertura APS
    cobertura_aps           NUMERIC,            -- % cobertura APS
    ativas_ff               INTEGER,            -- equipes de saúde da família ativas
    equipe_esf              INTEGER,            -- equipes de saúde da família
    equipe_emsi             INTEGER,            -- equipes multiprofissionais
    total_vagas_ativas      INTEGER,            -- total de vagas ativas
    ocupadas                INTEGER,            -- vagas ocupadas
    -- IVS / Vulnerabilidade
    categoria_ivs           SMALLINT,           -- categoria IVS (1-5)
    -- Metadados
    dt_snapshot             DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_sisab_aps PRIMARY KEY (codigo_municipio, dt_referencia, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS ix_sisab_codigo_municipio ON clean.sisab_aps (codigo_municipio);
CREATE INDEX IF NOT EXISTS ix_sisab_dt_referencia ON clean.sisab_aps (dt_referencia);
CREATE INDEX IF NOT EXISTS ix_sisab_dt_snapshot ON clean.sisab_aps (dt_snapshot);

-- Comentários
COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-*. Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot.';
COMMENT ON COLUMN clean.sisab_aps.codigo_municipio IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.sisab_aps.dt_referencia IS 'Mês de referência (primeiro dia do mês)';
COMMENT ON COLUMN clean.sisab_aps.cobertura_aps IS 'Cobertura APS (%)';
COMMENT ON COLUMN clean.sisab_aps.ativas_ff IS 'Equipes de saúde da família ativas (soma)';
COMMENT ON COLUMN clean.sisab_aps.equipe_esf IS 'Equipes de saúde da família (eSF)';
COMMENT ON COLUMN clean.sisab_aps.equipe_emsi IS 'Equipes multiprofissionais (eMultiequipes/NASF)';
COMMENT ON COLUMN clean.sisab_aps.total_vagas_ativas IS 'Total de vagas ativas';
COMMENT ON COLUMN clean.sisab_aps.ocupadas IS 'Vagas ocupadas (para efetividade)';
COMMENT ON COLUMN clean.sisab_aps.categoria_ivs IS 'Categoria IVS do Ministério da Saúde (1-5, 1=maior vulnerabilidade)';
COMMENT ON COLUMN clean.sisab_aps.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.sisab_aps'::text,
       'API SISAB/PIMMB'::text,
       'https://apidadosabertos.saude.gov.br/atencao-primaria/'::text,
       'CC BY 3.0 (dados abertos SUS)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: sisab_aps (agregados municipais mensais)'
FROM clean.sisab_aps;

COMMIT;