-- Revert edumaps:gestor_documentos from pg
-- requires: gestor_respostas

BEGIN;

  DROP TABLE IF EXISTS clean.escola_documentos_auditoria CASCADE;
  DROP TABLE IF EXISTS clean.escola_documentos_versoes CASCADE;
  DROP TABLE IF EXISTS clean.escola_documentos CASCADE;
  DROP TABLE IF EXISTS clean.pastas_escolares CASCADE;

COMMIT;