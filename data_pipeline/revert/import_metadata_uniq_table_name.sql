-- Revert edumaps:import_metadata_uniq_table_name to pg
-- requires: import_metadata_uniq_table_name
--
-- =================================================================
-- AVISO: este revert NÃO é um rollback completo.
--
-- O passo 1 do deploy apagou a linha duplicada de
-- clean.censo_data_dictionary. Reverter a restrição recria a
-- possibilidade de duplicar, mas não ressuscita a linha apagada —
-- e não deve: era uma cópia mais antiga da mesma tabela, e o deploy
-- mantém a versão mais recente (retrieved_at mais alto).
--
-- Se for mesmo preciso reconstruir o estado anterior, o caminho é
-- reexecutar a extracção de clean.censo_data_dictionary.
-- =================================================================

BEGIN;

ALTER TABLE clean.import_metadata
  DROP CONSTRAINT IF EXISTS import_metadata_table_name_key;

COMMIT;