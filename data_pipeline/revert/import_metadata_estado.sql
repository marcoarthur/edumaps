-- Revert edumaps:import_metadata_estado from pg
--
-- Remove as colunas de estado e o manifesto. O estado das tentativas e os
-- manifestos registrados desde o deploy SE PERDEM (os arquivos brutos em
-- /srv/edumaps/raw continuam no disco).

BEGIN;

ALTER TABLE clean.import_metadata
  DROP CONSTRAINT IF EXISTS import_metadata_raw_manifest_lista_check,
  DROP CONSTRAINT IF EXISTS import_metadata_ultimo_status_check;

ALTER TABLE clean.import_metadata
  DROP COLUMN IF EXISTS raw_manifest,
  DROP COLUMN IF EXISTS ultima_tentativa_em,
  DROP COLUMN IF EXISTS ultimo_motivo,
  DROP COLUMN IF EXISTS ultimo_status;

COMMIT;
