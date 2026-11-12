-- Revert edumaps:planos_gestao from pg

BEGIN;

  DROP TABLE clean.planos_auditoria;
  DROP TRIGGER trg_planos_acoes_meta_do_objetivo ON clean.planos_acoes;
  DROP FUNCTION clean.planos_acoes_meta_do_objetivo();
  DROP TABLE clean.planos_acoes;
  DROP TABLE clean.planos_metas;
  DROP TABLE clean.planos_objetivos;
  DROP TABLE clean.planos_gestao;

COMMIT;
