-- Carga do piloto de isócrona (#278) em clean.isocrona_escolar.
-- Roda no host do banco (o CSV foi enviado para /tmp).
--
-- Idempotente: substitui as linhas das escolas presentes no CSV — recarregar
-- o piloto não duplica (PK: co_entidade, tempo_minutos, grid_id, dt_snapshot).

BEGIN;

CREATE TEMP TABLE tmp_isocrona (
  co_entidade     BIGINT,
  codigo_ibge     TEXT,
  tempo_minutos   SMALLINT,
  grid_id         TEXT,
  resolucao_h3    SMALLINT,
  populacao_grade INTEGER
) ON COMMIT DROP;

\copy tmp_isocrona FROM '/tmp/isocrona_escolar.csv' WITH (FORMAT csv, HEADER)

DELETE FROM clean.isocrona_escolar e
 USING tmp_isocrona t
 WHERE e.co_entidade = t.co_entidade;

INSERT INTO clean.isocrona_escolar (
  codigo_ibge, co_entidade, tempo_minutos, grid_id, resolucao_h3,
  populacao_grade, tileset_origin, tileset_build_date, engine,
  engine_version, dt_snapshot
)
SELECT t.codigo_ibge,
       t.co_entidade,
       t.tempo_minutos,
       t.grid_id,
       t.resolucao_h3,
       t.populacao_grade,
       'geofabrik_sudeste_2026-10',   -- extract OSM recortado de ES em 2026-10-19
       DATE '2026-10-19',
       'valhalla',
       '3.5.1',                       -- medido em GET /status
       DATE '2026-10-19'
  FROM tmp_isocrona t;

SELECT 'linhas: ' || count(*) ||
       ' | escolas: ' || count(DISTINCT co_entidade) ||
       ' | com população: ' || count(*) FILTER (WHERE populacao_grade IS NOT NULL)
  FROM clean.isocrona_escolar;

COMMIT;
