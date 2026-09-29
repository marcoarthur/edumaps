-- Deploy edumaps:school_osm_query to pg
-- requires: osm_generalize
--
-- Seleção atual de POIs OSM por escola (e carimbo de atualização): qual
-- raio e quais catálogos (perfis) geraram o buffer, e o digest da última
-- query. Serve ao botão "Equipamentos no entorno" do Painel do Gestor
-- (recência < 7 dias, upsert e status).

BEGIN;

CREATE TABLE IF NOT EXISTS clean.school_osm_query (
  co_entidade  BIGINT NOT NULL,
  nu_ano_censo INTEGER NOT NULL,
  raio         INTEGER NOT NULL,
  profiles     JSONB NOT NULL,
  digest       TEXT REFERENCES clean.osm_query(digest) ON DELETE SET NULL,
  updated_at   TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (co_entidade, nu_ano_censo)
);

COMMIT;
