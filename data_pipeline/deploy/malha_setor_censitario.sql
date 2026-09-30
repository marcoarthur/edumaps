-- Deploy edumaps:malha_setor_censitario to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0
-- requires: extensions

BEGIN;

-- =================================================================
-- MALHA DE SETOR CENSITÁRIO IBGE 2022
-- ATENÇÃO: Arquivo GPKG ~748 MB - não é baixado durante deploy.
-- A tabela é criada vazia; população via script separado (geobr R package
-- ou download manual do GPKG + ogr_fdw).
-- =================================================================

DROP TABLE IF EXISTS clean.malha_setor_censitario;
CREATE TABLE clean.malha_setor_censitario (
    codigo_setor   TEXT NOT NULL,           -- 15 dígitos (7 município + 8 setor)
    codigo_ibge    TEXT NOT NULL,           -- 7 dígitos (município)
    nome_municipio TEXT,
    sigla_uf       CHAR(2),
    situacao_setor TEXT,                    -- urbano/rural
    geometry       geometry(MULTIPOLYGON, 4674),

    CONSTRAINT pk_malha_setor_censitario PRIMARY KEY (codigo_setor),
    CONSTRAINT enforce_valid_geometry CHECK (ST_IsValid(geometry))
);

-- Índices
CREATE INDEX IF NOT EXISTS ix_malha_setor_geometry ON clean.malha_setor_censitario USING GIST (geometry);
CREATE INDEX IF NOT EXISTS ix_malha_setor_codigo_ibge ON clean.malha_setor_censitario (codigo_ibge);
CREATE INDEX IF NOT EXISTS ix_malha_setor_codigo_setor ON clean.malha_setor_censitario (codigo_setor);
CREATE INDEX IF NOT EXISTS ix_malha_setor_uf ON clean.malha_setor_censitario (sigla_uf);

-- FK para malha_municipio
ALTER TABLE clean.malha_setor_censitario
  ADD CONSTRAINT fk_malha_setor_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setor censitário IBGE 2022 (estrutura criada, dados a popular via geobr/ogr_fdw). 316.574 setores esperados, SRID 4674.';
COMMENT ON COLUMN clean.malha_setor_censitario.codigo_setor IS 'Código do setor censitário (15 dígitos: 7 município + 8 setor) - PK';
COMMENT ON COLUMN clean.malha_setor_censitario.codigo_ibge IS 'Código IBGE do município (7 dígitos) - FK para malha_municipio';
COMMENT ON COLUMN clean.malha_setor_censitario.nome_municipio IS 'Nome do município';
COMMENT ON COLUMN clean.malha_setor_censitario.sigla_uf IS 'Sigla da UF';
COMMENT ON COLUMN clean.malha_setor_censitario.situacao_setor IS 'Situação do setor (urbano/rural)';
COMMENT ON COLUMN clean.malha_setor_censitario.geometry IS 'Geometria MULTIPOLYGON SRID 4674';

-- Registro de metadados (tabela criada vazia)
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.malha_setor_censitario'::text,
       'BR_Setor_Censitario_2022.gpkg (IBGE Geoftp)'::text,
       'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_setores_censitarios/setor_censitario_2022/Brasil/BR_Setor_Censitario_2022.gpkg'::text,
       'Domínio público (IBGE)'::text,
       NOW(),
       0::bigint,
       'Tabela criada vazia - população via script separado (geobr R package ou ogr_fdw manual). GPKG ~748 MB.'
FROM (SELECT 1) x;

COMMIT;