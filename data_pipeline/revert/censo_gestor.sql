-- Revert edumaps:censo_gestor from pg

BEGIN;

  DROP TABLE clean.gestor_escolar;

COMMIT;
