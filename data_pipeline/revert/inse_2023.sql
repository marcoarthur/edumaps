-- Revert edumaps:inse_2023 from pg

BEGIN;

  -- Revert step: add_inse_2023
  DROP TABLE IF EXISTS clean.inse CASCADE;
  -- Opcional: limpar metadados referentes a esta tabela (mantemos histórico, mas pode-se deletar)
  DELETE FROM clean.import_metadata WHERE table_name = 'clean.inse' AND source_file = 'inse_2023.csv';

COMMIT;
