-- Deploy edumaps:cnes_estabelecimentos to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- CNES - ESTABELECIMENTOS DE SAÚDE (SANITIZADO)
-- Apenas campos não-PII: codigo_cnes, codigo_municipio, codigo_tipo_unidade,
-- status, lat/long, data_atualizacao, dt_snapshot
-- =================================================================

DROP TABLE IF EXISTS clean.cnes_estabelecimentos;
CREATE TABLE clean.cnes_estabelecimentos (
    codigo_cnes                 BIGINT NOT NULL,
    codigo_municipio            TEXT NOT NULL,      -- 7 dígitos IBGE
    codigo_tipo_unidade         SMALLINT NOT NULL,
    status                      SMALLINT NOT NULL,  -- 1=ativo, 0=inativo
    latitude                    NUMERIC(10,8),
    longitude                   NUMERIC(11,8),
    data_atualizacao            DATE,
    dt_snapshot                 DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_cnes_estabelecimentos PRIMARY KEY (codigo_cnes, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS ix_cnes_codigo_municipio ON clean.cnes_estabelecimentos (codigo_municipio);
CREATE INDEX IF NOT EXISTS ix_cnes_codigo_tipo ON clean.cnes_estabelecimentos (codigo_tipo_unidade);
CREATE INDEX IF NOT EXISTS ix_cnes_status ON clean.cnes_estabelecimentos (status);
CREATE INDEX IF NOT EXISTS ix_cnes_dt_snapshot ON clean.cnes_estabelecimentos (dt_snapshot);
CREATE INDEX IF NOT EXISTS ix_cnes_geometry ON clean.cnes_estabelecimentos USING GIST (
    ST_SetSRID(ST_MakePoint(longitude, latitude), 4674)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Comentários
COMMENT ON TABLE clean.cnes_estabelecimentos IS 'Estabelecimentos CNES sanitizados (sem PII). Apenas: codigo_cnes, codigo_municipio, codigo_tipo_unidade, status, lat/long, data_atualizacao, dt_snapshot. Sanitizado na ingestão: descartados nome_razao_social, nome_fantasia, CNPJ, telefone, e-mail, endereço/bairro.';
COMMENT ON COLUMN clean.cnes_estabelecimentos.codigo_cnes IS 'Código CNES do estabelecimento (PK composta com dt_snapshot)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.codigo_municipio IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.codigo_tipo_unidade IS 'Código do tipo de unidade (ver cnes_tipounidades)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.status IS '1=Ativo, 0=Inativo';
COMMENT ON COLUMN clean.cnes_estabelecimentos.latitude IS 'Latitude (graus decimais)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.longitude IS 'Longitude (graus decimais)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.data_atualizacao IS 'Data de atualização do registro no CNES';
COMMENT ON COLUMN clean.cnes_estabelecimentos.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.cnes_estabelecimentos'::text,
       'API CNES estabelecimentos'::text,
       'https://apidadosabertos.saude.gov.br/cnes/estabelecimentos'::text,
       'CC BY-ND 3.0 (dados abertos SUS)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: cnes_estabelecimentos (sanitizado, sem PII)'
FROM clean.cnes_estabelecimentos;

COMMIT;