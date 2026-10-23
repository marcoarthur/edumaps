-- Revert edumaps:isocrona_escolar_indices_minimos from pg
--
-- Recria os 4 índices secundários removidos no deploy. Índices secundários
-- levam tempo para reconstruir numa tabela grande (16,6 M linhas no SP) — o
-- revert existe para integridade do Sqitch, não para uso rotineiro.

BEGIN;

CREATE INDEX IF NOT EXISTS idx_isocrona_co_entidade ON clean.isocrona_escolar (co_entidade);
CREATE INDEX IF NOT EXISTS idx_isocrona_grid ON clean.isocrona_escolar (grid_id);
CREATE INDEX IF NOT EXISTS idx_isocrona_tempo ON clean.isocrona_escolar (tempo_minutos);
CREATE INDEX IF NOT EXISTS idx_isocrona_dt_snapshot ON clean.isocrona_escolar (dt_snapshot);

COMMENT ON TABLE clean.isocrona_escolar IS 'Isocronas escolares (OSRM/Valhalla auto-hospedados). Agregação em grade H3 (resolução 10 ≈ 1km), NUNCA por escola isolada. Tileset extraído uma vez, auto-hospedado. Engine version e tileset_build_date registrados.';

COMMIT;
