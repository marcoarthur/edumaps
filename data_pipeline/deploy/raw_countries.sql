-- Deploy edumaps:raw_countries to pg
-- requires: extensions

BEGIN;

-- Configurar servidor FDW para dados de países (arquivo local)
DROP SERVER IF EXISTS fds_geojson CASCADE;
  CREATE SERVER fds_geojson
    FOREIGN DATA WRAPPER ogr_fdw
    OPTIONS(
      datasource '/vsicurl/https://cdn.jsdelivr.net/gh/johan/world.geo.json/countries.geo.json',
      format 'GeoJSON'
    );

  -- Importar schema foreign para raw
  IMPORT FOREIGN SCHEMA ogr_all
  FROM SERVER fds_geojson INTO raw;

  -- Criar tabela limpa no schema clean, corrigindo geometrias problemáticas
  DROP TABLE IF EXISTS clean.countries;
  CREATE TABLE clean.countries AS
  SELECT 
      ROW_NUMBER() OVER () as id,
      name,
      CASE 
          WHEN ST_IsValid(geom) THEN geom::geography
          ELSE ST_MakeValid(geom)::geography  -- Corrigir geometrias inválidas
      END AS geometry
  FROM raw.countries_geo;

  -- Adicionar constraints e índices (agora todas as geometrias devem ser válidas)
  ALTER TABLE clean.countries 
    ADD CONSTRAINT pk_countries PRIMARY KEY (id),
    ADD CONSTRAINT enforce_geography_geometry CHECK (ST_IsValid(geometry::geometry));

  CREATE INDEX ix_countries_geometry ON clean.countries USING GIST (geometry);
  CREATE INDEX ix_countries_name ON clean.countries (name);

  -- Comentários para documentação
  COMMENT ON TABLE clean.countries IS 'Dados limpos de países com geometrias válidas em geography. Geometrias inválidas foram corrigidas com ST_MakeValid';
  COMMENT ON COLUMN clean.countries.id IS 'Identificador único gerado sequencialmente';
  COMMENT ON COLUMN clean.countries.name IS 'Nome do país';
  COMMENT ON COLUMN clean.countries.geometry IS 'Geometria válida do país em formato geography (corrigida se necessário)';

  COMMENT ON SERVER fds_geojson IS 'Servidor FDW para dados GeoJSON de países';
  COMMENT ON FOREIGN TABLE raw.countries_geo IS 'Dados brutos de países importados via OGR_FDW';

COMMIT;
