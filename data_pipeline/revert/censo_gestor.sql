-- Revert edumaps:censo_gestor from pg

BEGIN;

  DROP TABLE IF EXISTS clean.gestor_escolar;

COMMIT;
