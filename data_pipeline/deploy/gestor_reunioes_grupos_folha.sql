-- Deploy edumaps:gestor_reunioes_grupos_folha to pg
-- requires: gestor_reunioes
--
-- Grupos pré-listados a partir da folha de pagamento (remuneracao_municipal).
-- A agenda é por escola: os grupos de origem 'folha' (Professores,
-- Administrativos, Outros) são criados por maintenance/backfill sem depender de
-- um gestor existente — por isso gestor_id passa a ser opcional. O gestor fica
-- registrado apenas quando ele mesmo cria/edita o grupo (origem 'manual').

BEGIN;

  ALTER TABLE clean.contato_grupos
    ALTER COLUMN gestor_id DROP NOT NULL;

  ALTER TABLE clean.contato_grupos
    ADD COLUMN origem text NOT NULL DEFAULT 'manual'
      CHECK (origem IN ('manual', 'folha'));

  COMMENT ON COLUMN clean.contato_grupos.gestor_id IS
    'Gestor que criou o grupo. NULL em grupos pré-listados pela folha de pagamento (origem folha); só gestores da escola associam grupos manuais.';

  COMMENT ON COLUMN clean.contato_grupos.origem IS
    '"manual": criado/importado pelo gestor (padrão); "folha": pré-listado pela categoria profissional da folha de pagamento (Professores/Administrativos/Outros).';

COMMIT;