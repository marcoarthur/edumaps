-- Revert edumaps:ibge_agregados from pg

BEGIN;

-- Remover registro do import_metadata
DELETE FROM clean.import_metadata
WHERE table_name = 'clean.ibge_agregados';

-- Dropar view
DROP VIEW IF EXISTS clean.v_ibge_municipio_ano;

-- Dropar tabela
DROP TABLE IF EXISTS clean.ibge_agregados;

COMMIT;