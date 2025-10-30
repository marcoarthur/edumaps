-- Deploy edumaps:raw_municipios_sp to pg
-- requires: extensions

BEGIN;

  -- Configurar servidor FDW para municípios de SP (IBGE 2024)
  DROP SERVER IF EXISTS fdw_municipios_sp CASCADE;
  CREATE SERVER fdw_municipios_sp
    FOREIGN DATA WRAPPER ogr_fdw
    OPTIONS(
      datasource '/vsizip//vsicurl/https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/SP/SP_Municipios_2024.zip',
      format 'ESRI Shapefile'
    );

  -- Importar schema foreign para raw
  IMPORT FOREIGN SCHEMA ogr_all FROM SERVER fdw_municipios_sp INTO raw;

  -- Criar tabela limpa no schema clean com nomenclatura semântica
  DROP TABLE IF EXISTS clean.municipios_sp;
  CREATE TABLE clean.municipios_sp AS
  SELECT
      fid as id_original,
      cd_mun as codigo_ibge,
      nm_mun as nome,
      nm_mun as nome_municipio,
      cd_rgi as codigo_regiao_imediata,
      nm_rgi as nome_regiao_imediata,
      cd_rgint as codigo_regiao_intermediaria,
      nm_rgint as nome_regiao_intermediaria,
      cd_uf as codigo_uf,
      nm_uf as nome_estado,
      sigla_uf as sigla_estado,
      cd_regia as codigo_regiao,
      nm_regia as nome_regiao,
      sigla_rg as sigla_regiao,
      cd_concu as codigo_concurso,
      nm_concu as nome_concurso,
      area_km2 as area_km2,
      CASE 
          WHEN ST_IsValid(geom) THEN ST_Multi(geom)::geometry(MULTIPOLYGON, 4674)
          ELSE ST_Multi(ST_MakeValid(geom))::geometry(MULTIPOLYGON, 4674)
      END AS geometry,
      NOT ST_IsValid(geom) as geometria_corrigida
  FROM raw.sp_municipios_2024;

  -- Adicionar constraints e índices
  ALTER TABLE clean.municipios_sp 
    ADD CONSTRAINT pk_municipios_sp PRIMARY KEY (codigo_ibge),
    ADD CONSTRAINT enforce_valid_geometry CHECK (ST_IsValid(geometry));

  -- Índices espaciais e de performance
  CREATE INDEX ix_municipios_sp_geometry ON clean.municipios_sp USING GIST (geometry);
  CREATE INDEX ix_municipios_sp_codigo_ibge ON clean.municipios_sp (codigo_ibge);
  CREATE INDEX ix_municipios_sp_nome ON clean.municipios_sp (nome);
  CREATE INDEX ix_municipios_sp_regiao_imediata ON clean.municipios_sp (codigo_regiao_imediata);
  CREATE INDEX ix_municipios_sp_regiao_intermediaria ON clean.municipios_sp (codigo_regiao_intermediaria);
  CREATE INDEX ix_municipios_sp_estado ON clean.municipios_sp (sigla_estado);

  -- Comentários para documentação
  COMMENT ON TABLE clean.municipios_sp IS 'Dados limpos de municípios de São Paulo (IBGE 2024) com nomenclatura semântica e geometrias validadas';
  COMMENT ON COLUMN clean.municipios_sp.id_original IS 'ID original do shapefile (fid)';
  COMMENT ON COLUMN clean.municipios_sp.codigo_ibge IS 'Código oficial do IBGE para o município';
  COMMENT ON COLUMN clean.municipios_sp.nome IS 'Nome do município';
  COMMENT ON COLUMN clean.municipios_sp.nome_municipio IS 'Nome completo do município (redundante para compatibilidade)';
  COMMENT ON COLUMN clean.municipios_sp.codigo_regiao_imediata IS 'Código da região imediata according to IBGE';
  COMMENT ON COLUMN clean.municipios_sp.nome_regiao_imediata IS 'Nome da região imediata';
  COMMENT ON COLUMN clean.municipios_sp.codigo_regiao_intermediaria IS 'Código da região intermediária';
  COMMENT ON COLUMN clean.municipios_sp.nome_regiao_intermediaria IS 'Nome da região intermediária';
  COMMENT ON COLUMN clean.municipios_sp.codigo_uf IS 'Código da Unidade Federativa';
  COMMENT ON COLUMN clean.municipios_sp.nome_estado IS 'Nome do estado';
  COMMENT ON COLUMN clean.municipios_sp.sigla_estado IS 'Sigla do estado (SP)';
  COMMENT ON COLUMN clean.municipios_sp.codigo_regiao IS 'Código da região geográfica';
  COMMENT ON COLUMN clean.municipios_sp.nome_regiao IS 'Nome da região geográfica';
  COMMENT ON COLUMN clean.municipios_sp.sigla_regiao IS 'Sigla da região geográfica';
  COMMENT ON COLUMN clean.municipios_sp.codigo_concurso IS 'Código do concurso (campo específico IBGE)';
  COMMENT ON COLUMN clean.municipios_sp.nome_concurso IS 'Nome do concurso (campo específico IBGE)';
  COMMENT ON COLUMN clean.municipios_sp.area_km2 IS 'Área do município em quilômetros quadrados';
  COMMENT ON COLUMN clean.municipios_sp.geometry IS 'Geometria do município em MULTIPOLYGON (SRID 4674)';
  COMMENT ON COLUMN clean.municipios_sp.geometria_corrigida IS 'Indica se a geometria original foi corrigida com ST_MakeValid';

  COMMENT ON SERVER fdw_municipios_sp IS 'Servidor FDW para dados de municípios de SP do IBGE (2024)';
  COMMENT ON FOREIGN TABLE raw.sp_municipios_2024 IS 'Dados brutos de municípios de São Paulo importados via OGR_FDW';

  -- Estatísticas para otimização do planner
  ANALYZE clean.municipios_sp;

COMMIT;
