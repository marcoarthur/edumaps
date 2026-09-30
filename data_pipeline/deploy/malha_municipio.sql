-- Deploy edumaps:malha_municipio to pg
-- requires: import_metadata_fase0
-- requires: raw_municipios_sp

BEGIN;

-- =================================================================
-- MALHA MUNICIPAL IBGE (a partir de clean.municipios_sp existente)
-- =================================================================

-- Criar tabela limpa no schema clean a partir de municipios_sp
DROP TABLE IF EXISTS clean.malha_municipio;
CREATE TABLE clean.malha_municipio AS
SELECT
    id_original,
    codigo_ibge,
    nome_municipio,
    sigla_estado as sigla_uf,
    area_km2,
    CASE
        WHEN ST_IsValid(geometry) THEN ST_Multi(geometry)::geometry(MULTIPOLYGON, 4674)
        ELSE ST_Multi(ST_MakeValid(geometry))::geometry(MULTIPOLYGON, 4674)
    END AS geometry,
    geometria_corrigida
FROM clean.municipios_sp;

-- Constraints e índices
ALTER TABLE clean.malha_municipio
  ADD CONSTRAINT pk_malha_municipio PRIMARY KEY (codigo_ibge),
  ADD CONSTRAINT enforce_valid_geometry CHECK (ST_IsValid(geometry));

-- Índices espaciais e de performance
CREATE INDEX IF NOT EXISTS ix_malha_municipio_geometry ON clean.malha_municipio USING GIST (geometry);
CREATE INDEX IF NOT EXISTS ix_malha_municipio_codigo_ibge ON clean.malha_municipio (codigo_ibge);
CREATE INDEX IF NOT EXISTS ix_malha_municipio_uf ON clean.malha_municipio (sigla_uf);

-- Comentários
COMMENT ON TABLE clean.malha_municipio IS 'Malha municipal IBGE 2024 (derivada de clean.municipios_sp) com geometrias validadas SRID 4674';
COMMENT ON COLUMN clean.malha_municipio.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.malha_municipio.nome_municipio IS 'Nome do município';
COMMENT ON COLUMN clean.malha_municipio.sigla_uf IS 'Sigla da UF';
COMMENT ON COLUMN clean.malha_municipio.area_km2 IS 'Área do município em km²';
COMMENT ON COLUMN clean.malha_municipio.geometry IS 'Geometria MULTIPOLYGON SRID 4674';
COMMENT ON COLUMN clean.malha_municipio.geometria_corrigida IS 'Indica se a geometria foi corrigida com ST_MakeValid';

-- Registro de metadados da importação
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.malha_municipio'::text,
       'clean.municipios_sp (derivado)'::text,
       'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.gpkg'::text,
       'Domínio público (IBGE)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: malha_municipio (derivado de clean.municipios_sp / raw_municipios_sp)'
FROM clean.malha_municipio;

COMMIT;