-- Revert edumaps:ranking_escolas from pg

BEGIN;

  -- Não fazemos DROP SCHEMA analytics aqui: o schema pode conter
  -- outras tabelas/objetos alheios a esta migration.
  DROP TABLE IF EXISTS analytics.ranking_escola;

COMMIT;
