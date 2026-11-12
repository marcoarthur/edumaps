-- Revert edumaps:planos_evidencias from pg

BEGIN;
  DELETE FROM clean.planos_auditoria WHERE entidade = 'evidencia';
  ALTER TABLE clean.planos_auditoria DROP CONSTRAINT planos_auditoria_entidade_check;
  ALTER TABLE clean.planos_auditoria ADD CONSTRAINT planos_auditoria_entidade_check
    CHECK (entidade IN ('plano', 'objetivo', 'meta', 'acao'));
  DROP TABLE clean.planos_evidencias;
COMMIT;
