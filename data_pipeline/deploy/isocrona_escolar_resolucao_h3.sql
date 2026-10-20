-- Deploy edumaps:isocrona_escolar_resolucao_h3 to pg
-- requires: mapbiomas_risco_carbono_nodata
--
-- #278: a coluna grid_id não diz a resolução H3 da célula, e o comentário do
-- schema original afirmava "resolução 10 ≈ 1 km" — falso (H3 r10 tem ~15 ha;
-- ~1 km² fica entre r7 e r8). O piloto de ES mediu, por escola:
--   15 min a pé (~2 km²)        -> r9: 18-25 células
--   45 min carro (~400-1800 km²) -> r7: 76-313 células (r9 daria 10k-15k)
-- A resolução passa a ser dado, não suposição do leitor (#278).

BEGIN;

ALTER TABLE clean.isocrona_escolar
  ADD COLUMN resolucao_h3 SMALLINT NOT NULL;

COMMENT ON COLUMN clean.isocrona_escolar.resolucao_h3 IS
'Resolução H3 da célula em grid_id (0..15), #278. Varia por horizonte: ~0,1 km² (r9) no alcance a pé, ~5 km² (r7) no de carro — medido no piloto de ES (2026-10-19).';

COMMENT ON COLUMN clean.isocrona_escolar.grid_id IS
'ID da célula da grade H3; a resolução está em resolucao_h3 (#278) — o texto antigo dizia "r10 ≈ 1km", o que é falso.';

COMMIT;
