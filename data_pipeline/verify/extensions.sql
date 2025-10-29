-- Verify edumaps:extensions on pg

BEGIN;

-- Verificar se as extensões principais foram instaladas
SELECT 
    COUNT(*) >= 10 as todas_extensoes_instaladas,
    COUNT(*) FILTER (WHERE extname = 'postgis') = 1 as tem_postgis,
    COUNT(*) FILTER (WHERE extname = 'postgis_raster') = 1 as tem_postgis_raster,
    COUNT(*) FILTER (WHERE extname = 'postgis_topology') = 1 as tem_postgis_topology,
    COUNT(*) FILTER (WHERE extname = 'fuzzystrmatch') = 1 as tem_fuzzystrmatch,
    COUNT(*) FILTER (WHERE extname = 'address_standardizer') = 1 as tem_address_standardizer,
    COUNT(*) FILTER (WHERE extname = 'uuid-ossp') = 1 as tem_uuid_ossp,
    COUNT(*) FILTER (WHERE extname = 'unaccent') = 1 as tem_unaccent,
    COUNT(*) FILTER (WHERE extname = 'ogr_fdw') = 1 as tem_ogr_fdw
FROM pg_extension 
WHERE extname IN (
    'postgis', 'postgis_raster', 'postgis_sfcgal', 'postgis_topology',
    'fuzzystrmatch', 'address_standardizer', 'uuid-ossp', 'unaccent', 'ogr_fdw'
);

-- Verificar se as extensões estão nos schemas corretos
SELECT 
    COUNT(*) = 4 as extensoes_nos_schemas_corretos,
    COUNT(*) FILTER (WHERE extname = 'postgis' AND extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'postgis')) = 1 as postgis_no_schema_correto,
    COUNT(*) FILTER (WHERE extname = 'postgis_raster' AND extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'postgis')) = 1 as raster_no_schema_correto,
    COUNT(*) FILTER (WHERE extname = 'fuzzystrmatch' AND extnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'contrib')) = 1 as fuzzystrmatch_no_schema_correto
FROM pg_extension;

ROLLBACK;
