-- Deploy edumaps:isocrona_escolar to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0
-- requires: extensions

BEGIN;

-- =================================================================
-- ISOCRONAS ESCOLARES (OSRM/VALHALLA AUTO-HOSPEDADOS)
-- Tileset extraído uma vez, auto-hospedado em container
-- NÃO usar instâncias públicas (sem SLA)
-- Agregação em grade de 1 km (NUNCA por escola isolada)
-- =================================================================

DROP TABLE IF EXISTS clean.isocrona_escolar;
CREATE TABLE clean.isocrona_escolar (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    co_entidade       BIGINT NOT NULL,    -- código da escola
    tempo_minutos     SMALLINT NOT NULL,  -- tempo de deslocamento (ex.: 15, 30, 45)
    grid_id           TEXT NOT NULL,      -- ID da célula da grade (ex.: "h3_10_8a2b...")
    -- Grade H3 (resolução 10 ≈ 66km edge, resolução 11 ≈ 24km, resolução 12 ≈ 8.8km)
    -- Resolução 10 ≈ 1km cells
    populacao_grade   INTEGER,            -- população na grade (Censo 2022)
    -- Metadados
    tileset_origin    TEXT NOT NULL,      -- ex.: 'geofabrik_brazil_2024-01', 'osm_pbf_2024-06'
    tileset_build_date DATE,              -- data de build do tileset
    engine            TEXT NOT NULL,      -- 'osrm' ou 'valhalla'
    engine_version    TEXT,               -- versão do motor
    dt_snapshot       DATE NOT NULL,      -- data do snapshot

    CONSTRAINT pk_isocrona_escolar PRIMARY KEY (co_entidade, tempo_minutos, grid_id, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_isocrona_codigo_ibge ON clean.isocrona_escolar (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_isocrona_co_entidade ON clean.isocrona_escolar (co_entidade);
CREATE INDEX IF NOT EXISTS idx_isocrona_tempo ON clean.isocrona_escolar (tempo_minutos);
CREATE INDEX IF NOT EXISTS idx_isocrona_grid ON clean.isocrona_escolar (grid_id);
CREATE INDEX IF NOT EXISTS idx_isocrona_dt_snapshot ON clean.isocrona_escolar (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.isocrona_escolar
  ADD CONSTRAINT fk_isocrona_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;



-- Comentários
COMMENT ON TABLE clean.isocrona_escolar IS 'Isocronas escolares (OSRM/Valhalla auto-hospedados). Agregação em grade H3 (resolução 10 ≈ 1km), NUNCA por escola isolada. Tileset extraído uma vez, auto-hospedado. Engine version e tileset_build_date registrados.';
COMMENT ON COLUMN clean.isocrona_escolar.codigo_ibge IS 'Código IBGE do município da escola';
COMMENT ON COLUMN clean.isocrona_escolar.co_entidade IS 'Código INEP da escola';
COMMENT ON COLUMN clean.isocrona_escolar.tempo_minutos IS 'Tempo de deslocamento em minutos (ex.: 15, 30, 45)';
COMMENT ON COLUMN clean.isocrona_escolar.grid_id IS 'ID da célula da grade H3 (resolução 10 ≈ 1km)';
COMMENT ON COLUMN clean.isocrona_escolar.populacao_grade IS 'População na grade (Censo 2022)';
COMMENT ON COLUMN clean.isocrona_escolar.tileset_origin IS 'Origem do tileset (ex.: geofabrik_brazil_2024-01, osm_pbf_2024-06)';
COMMENT ON COLUMN clean.isocrona_escolar.tileset_build_date IS 'Data de build do tileset (fixa para reprodutibilidade)';
COMMENT ON COLUMN clean.isocrona_escolar.engine IS 'Engine de roteamento: osrm ou valhalla';
COMMENT ON COLUMN clean.isocrona_escolar.engine_version IS 'Versão do engine de roteamento';
COMMENT ON COLUMN clean.isocrona_escolar.dt_snapshot IS 'Data do snapshot (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.isocrona_escolar'::text,
       'OSRM/Valhalla auto-hospedado (tileset Geofabrik Brazil)'::text,
       'router.project-osrm.org (demo) -> auto-hospedado'::text,
       'BSD-2-Clause (OSRM) / MIT (Valhalla)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: isocrona_escolar. Tileset extraído uma vez, auto-hospedado. Agregação em grade H3 (não por escola isolada).'
FROM clean.isocrona_escolar;

COMMIT;