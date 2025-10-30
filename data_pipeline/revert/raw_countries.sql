-- Revert edumaps:raw_countries from pg

BEGIN;

-- Remover tabela limpa
DROP TABLE IF EXISTS clean.countries;

-- Remover servidor FDW e tabelas foreign
DROP SERVER IF EXISTS fds_geojson CASCADE;

COMMIT;
