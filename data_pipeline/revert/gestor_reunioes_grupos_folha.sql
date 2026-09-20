-- Revert edumaps:gestor_reunioes_grupos_folha from pg

BEGIN;

  ALTER TABLE clean.contato_grupos
    DROP COLUMN origem;

  -- Restaura NOT NULL: grupos de origem folha ficariam órfãos; remova-os.
  DELETE FROM clean.contato_grupos WHERE gestor_id IS NULL;

  ALTER TABLE clean.contato_grupos
    ALTER COLUMN gestor_id SET NOT NULL;

COMMIT;