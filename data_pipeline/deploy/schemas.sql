-- Deploy edumaps:schemas to pg

BEGIN;

  CREATE SCHEMA IF NOT EXISTS raw;        -- Dados importados brutos, sem tratamento
  CREATE SCHEMA IF NOT EXISTS clean;      -- Dados tratados e prontos para uso
  CREATE SCHEMA IF NOT EXISTS analytics;  -- Tabelas geradas a partir de análises
  CREATE SCHEMA IF NOT EXISTS postgis;    -- Extensões PostGIS
  CREATE SCHEMA IF NOT EXISTS contrib;    -- Extensões contrib

  -- Configurar search_path para o banco (usando CURRENT_DATABASE())
  DO $$ 
    BEGIN
      EXECUTE format('ALTER DATABASE %I SET search_path = clean, analytics, raw, public, postgis, contrib, topology, tiger', current_database());
  END $$;

COMMIT;
