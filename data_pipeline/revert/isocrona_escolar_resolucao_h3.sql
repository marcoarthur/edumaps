-- Revert edumaps:isocrona_escolar_resolucao_h3 from pg
--
-- Remove a coluna e volta ao texto antigo do comentário de grid_id. As linhas
-- já carregadas com resolução mista (r9 a pé, r7 de carro) ficam sem o rótulo
-- — nesse caso, recarregue o piloto antes de reverter.

BEGIN;

ALTER TABLE clean.isocrona_escolar DROP COLUMN resolucao_h3;

COMMENT ON COLUMN clean.isocrona_escolar.grid_id IS 'ID da célula da grade H3 (resolução 10 ≈ 1km)';

COMMIT;
