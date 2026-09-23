-- Deploy edumaps:edumaps_leitor_role to pg
-- requires: schemas
--
-- Role somente-leitura para o assistente NL/SQL (Perguntas ao Censo).
-- O backend roda o job na fila Minion, o motor R (edumapsr) conecta como
-- esta role via pg_service (`[edumaps_leitor]`) e executa SQL gerado por LLM.
-- A defesa real contra DROP/DELETE/UPDATE/INSERT/etc. é esta role:
--   * NOLOGIN por padrão (habilita LOGIN + senha só no deploy, sem credencial
--     no repositório);
--   * SELECT apenas em clean.* e analytics.*;
--   * default_transaction_read_only = on  (nenhuma transação escreve);
--   * statement_timeout curto (LLM errar longe de travar o banco).

BEGIN;

  DO $$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
      CREATE ROLE edumaps_leitor NOLOGIN;
    END IF;
  END $$;

  -- ALL TABLES cobre tabelas, views E materialized views (não existe
  -- GRANT ... ON ALL MATERIALIZED VIEWS no PostgreSQL).
  GRANT USAGE ON SCHEMA clean, analytics TO edumaps_leitor;
  GRANT SELECT ON ALL TABLES IN SCHEMA clean, analytics TO edumaps_leitor;
  GRANT SELECT ON ALL SEQUENCES IN SCHEMA clean, analytics TO edumaps_leitor;

  ALTER DEFAULT PRIVILEGES IN SCHEMA clean
    GRANT SELECT ON TABLES TO edumaps_leitor;
  ALTER DEFAULT PRIVILEGES IN SCHEMA clean
    GRANT SELECT ON SEQUENCES TO edumaps_leitor;

  ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
    GRANT SELECT ON TABLES TO edumaps_leitor;
  ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
    GRANT SELECT ON SEQUENCES TO edumaps_leitor;

  ALTER ROLE edumaps_leitor
    SET default_transaction_read_only = on;
  ALTER ROLE edumaps_leitor
    SET statement_timeout = '30s';

COMMIT;