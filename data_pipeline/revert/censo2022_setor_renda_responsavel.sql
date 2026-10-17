-- Revert edumaps:censo2022_setor_renda_responsavel from pg
--
-- Remove as colunas novas e repõe os COMMENTs de comments_ingestao_p2.

BEGIN;

COMMENT ON COLUMN clean.censo2022_setor.rend_media IS
  'Sem fonte nos Agregados por Setores do Censo 2022 (rendimento não publicado por setor). NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.rend_per_capita IS
  'Sem fonte nos Agregados por Setores do Censo 2022 (rendimento não publicado por setor). NULL por desenho (#238).';

ALTER TABLE clean.censo2022_setor
  DROP COLUMN IF EXISTS rend_mediana,
  DROP COLUMN IF EXISTS rend_resp_count;

COMMIT;
