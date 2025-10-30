-- Revert edumaps:raw_municipios_sp from pg

BEGIN;

  -- Remover tabela limpa
  DROP TABLE IF EXISTS clean.municipios_sp;

  -- Remover servidor FDW
  DROP SERVER IF EXISTS fdw_municipios_sp CASCADE;

COMMIT;
