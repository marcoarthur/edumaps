-- Revert edumaps:leitor_grants_explicitos from pg
-- Devolve o SELECT automático em clean (concedido pelo usuário do deploy,
-- como na edumaps_leitor_role).

BEGIN;

  DO $$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
      RETURN;
    END IF;
    ALTER DEFAULT PRIVILEGES IN SCHEMA clean GRANT SELECT ON TABLES TO edumaps_leitor;
    ALTER DEFAULT PRIVILEGES IN SCHEMA clean GRANT SELECT ON SEQUENCES TO edumaps_leitor;
  END
  $$;

COMMIT;
