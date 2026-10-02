-- Deploy edumaps:import_metadata_uniq_table_name to pg
-- requires: brazilcrime_sem_patrimoniais
--
-- =================================================================
-- Unicidade em clean.import_metadata.table_name
-- Issue #164 (defeito transversal, descoberto ao correr o BrazilCrime)
--
-- Porquê:
-- O helper upsert_metadata() em
-- backend/lib/EduMaps/Ingestion/Job/Base.pm faz
--
--   INSERT INTO clean.import_metadata (...) VALUES (...)
--   ON CONFLICT (table_name) DO UPDATE SET ...
--
-- Mas clean.import_metadata NUNCA teve restrição de unicidade em
-- table_name: só tinha a PK id_import e um índice não-únique em
-- source_url. Um ON CONFLICT (table_name) sem índice único correspondente
-- falha sempre, com:
--
--   ERROR: there is no unique or exclusion constraint matching the
--          ON CONFLICT specification
--
-- Isto atinge TODOS os jobs que chamam upsert_metadata(), não só o
-- BrazilCrime: o erro aparece no fim da ingestão, depois de o R já ter
-- corrido e de o CSV já ter sido carregado. Ou seja, a ingestão
-- "falha" no último passo e quem não ler o log a fundo julga que
-- correu.
--
-- Antes de criar a restrição é preciso remover o duplicado que já
-- existe: clean.censo_data_dictionary tem 2 linhas. Mantém-se a mais
-- recente por retrieved_at/import_timestamp, que é a que reflecte a
-- última extracção.
-- =================================================================

BEGIN;

-- 1. Deduplicar, mantendo a linha mais recente de cada table_name.
--    id_import NÃO entra no critério: um id mais alto não implica uma
--    extracção mais recente, e o texto da nota pode ter mudado sem o
--    id.
DELETE FROM clean.import_metadata m
 WHERE m.id_import NOT IN (
         SELECT DISTINCT ON (table_name) id_import
           FROM clean.import_metadata
          ORDER BY table_name,
                   COALESCE(retrieved_at, import_timestamp) DESC NULLS LAST,
                   id_import DESC);

-- 2. Restrição de unicidade. É o que torna o ON CONFLICT do Base.pm
--    legal em vez de um erro garantido.
ALTER TABLE clean.import_metadata
  ADD CONSTRAINT import_metadata_table_name_key UNIQUE (table_name);

COMMIT;