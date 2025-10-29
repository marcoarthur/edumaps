-- Deploy edumaps:extensions to pg

BEGIN;

  -- Instalar extensões PostGIS no schema apropriado
  CREATE EXTENSION IF NOT EXISTS postgis SCHEMA postgis;
  CREATE EXTENSION IF NOT EXISTS postgis_raster SCHEMA postgis;
  CREATE EXTENSION IF NOT EXISTS postgis_sfcgal SCHEMA postgis;
  CREATE EXTENSION IF NOT EXISTS postgis_topology;
  CREATE EXTENSION IF NOT EXISTS fuzzystrmatch SCHEMA contrib;
  CREATE EXTENSION IF NOT EXISTS address_standardizer SCHEMA contrib;

  -- Extensões utilitárias adicionais que serão úteis
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;  -- Para gerar UUIDs
  CREATE EXTENSION IF NOT EXISTS unaccent SCHEMA contrib;    -- Para buscas sem acento
  CREATE EXTENSION IF NOT EXISTS ogr_fdw SCHEMA postgis;

  COMMENT ON EXTENSION postgis IS 'Extensão principal PostGIS para dados geoespaciais';
  COMMENT ON EXTENSION postgis_raster IS 'Suporte a dados raster no PostGIS';
  COMMENT ON EXTENSION postgis_sfcgal IS 'Algoritmos geoespaciais avançados via SFCGAL';
  COMMENT ON EXTENSION postgis_topology IS 'Modelagem topológica para dados geoespaciais';
  COMMENT ON EXTENSION address_standardizer IS 'modelador de endereços ou padronizador para endereços';
COMMIT;
