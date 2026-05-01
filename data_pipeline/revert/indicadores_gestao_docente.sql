-- Revert edumaps:indicadores_gestao_docente from pg

BEGIN;

  DROP FUNCTION IF EXISTS clean.gestor_indicators(BIGINT);
  DROP FUNCTION IF EXISTS clean.docente_indicators(BIGINT);
  DROP FUNCTION IF EXISTS clean.school_indicators(BIGINT);

COMMIT;
