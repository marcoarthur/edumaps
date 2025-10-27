/*
Initialize the gisdb GIS database for map_app.pl 
- create gisdb database
- create all extensions
- create all schemas
- create all tables
- import data from external datasources
*/
BEGIN;
  CREATE DATABASE gisdb;
  ALTER DATABASE gisdb SET search_path=public,postgis,tiger,contrib;

  CREATE SCHEMA IF NOT EXISTS postgis;
  CREATE SCHEMA IF NOT EXISTS contrib;
  CREATE EXTENSION postgis SCHEMA postgis;

  CREATE EXTENSION postgis_raster SCHEMA postgis;

  CREATE EXTENSION postgis_sfcgal SCHEMA postgis;
  CREATE EXTENSION postgis_topology;
  CREATE EXTENSION fuzzystrmatch SCHEMA contrib;
  CREATE EXTENSION address_standardizer SCHEMA contrib;
  CREATE EXTENSION postgis_tiger_geocoder;

  CREATE SCHEMA IF NOT EXISTS foss4g2021;
  CREATE SCHEMA IF NOT EXISTS staging;

  ALTER DATABASE gisdb SET search_path=foss4g2021,public,postgis,contrib,topology,tiger;
  CREATE EXTENSION IF NOT EXISTS ogr_fdw SCHEMA postgis;
  CREATE EXTENSION IF NOT EXISTS unaccent SCHEMA foss4g2021;

  SELECT ogr_fdw_version();
  -- check all kind of files that we can read from
  SELECT driver
  FROM unnest(ogr_fdw_drivers()) AS driver
  ORDER BY driver;
  SHOW search_path;

  DROP SERVER IF EXISTS fds_geojson CASCADE;
  CREATE SERVER fds_geojson
    FOREIGN DATA WRAPPER ogr_fdw
    OPTIONS(
      datasource '/vsicurl/https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json', format 'GeoJSON'
    );
  IMPORT FOREIGN SCHEMA ogr_all
  FROM SERVER fds_geojson INTO staging;

  SELECT id,name FROM staging.countries_geo;

  --make into a physical table
  DROP TABLE IF EXISTS countries;
  SELECT id, name, geom::geography AS geog
  INTO countries
  FROM staging.countries_geo;

  -- both zipped web file also
  DROP SERVER IF EXISTS municipios_sp CASCADE;
  CREATE SERVER municipios_sp
    FOREIGN DATA WRAPPER ogr_fdw
    OPTIONS(
      datasource '/vsizip//vsicurl/https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/SP/SP_Municipios_2024.zip',
      format 'ESRI Shapefile'
    );

  IMPORT FOREIGN SCHEMA ogr_all FROM SERVER municipios_sp INTO staging;

  -- landuse for brazil
  DROP SERVER IF EXISTS landuse_br CASCADE;
  CREATE SERVER landuse_br
    FOREIGN DATA WRAPPER ogr_fdw
    OPTIONS(
      datasource '/data/landuse/',
      format 'ESRI Shapefile'
    );
  IMPORT FOREIGN SCHEMA ogr_all FROM SERVER landuse_br INTO staging;

  -- build real tables from the FOREIGN tables linked
  DROP TABLE IF EXISTS municipios_sp;
  CREATE TABLE municipios_sp AS
    SELECT
      fid , 
      ST_Multi(geom)::geography(MULTIPOLYGON,4674) AS geog,
      cd_mun , nm_mun , cd_rgi , nm_rgi , cd_rgint , nm_rgint , cd_uf , nm_uf , sigla_uf , cd_regia , nm_regia , sigla_rg , cd_concu , nm_concu , area_km2 
    FROM staging.sp_municipios_2024;

  ALTER   TABLE municipios_sp ADD CONSTRAINT pk_municipios_sp PRIMARY KEY(fid);
  CREATE  INDEX ix_municipios_geog_spgist ON municipios_sp USING spgist(geog);
  ANALYZE municipios_sp;
COMMIT;
