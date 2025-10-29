-- Revert edumaps:extensions from pg

BEGIN;

-- Remover extensões na ordem inversa (evitar dependências)
  DROP EXTENSION IF EXISTS ogr_fdw;
  DROP EXTENSION IF EXISTS unaccent;
  DROP EXTENSION IF EXISTS "uuid-ossp";
  DROP EXTENSION IF EXISTS address_standardizer;
  DROP EXTENSION IF EXISTS fuzzystrmatch;
  DROP EXTENSION IF EXISTS postgis_topology;
  DROP EXTENSION IF EXISTS postgis_sfcgal;
  DROP EXTENSION IF EXISTS postgis_raster;
  DROP EXTENSION IF EXISTS postgis;

COMMIT;
