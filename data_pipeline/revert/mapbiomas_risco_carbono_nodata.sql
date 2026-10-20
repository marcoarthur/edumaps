-- Revert edumaps:mapbiomas_risco_carbono_nodata from pg
--
-- IRREVERSÍVEL: os valores de nodata mascarados não existem em lugar nenhum
-- — eram artefatos de raster (ex. -3.4e38) descartados pelo loader. Repor a
-- situação anterior exige reexecutar a extração dos 690 buffers afetados
-- (job MapBiomasRisco, uf/raio das escolas em clean.mapbiomas_escola_risco
-- com solo_carbono_medio IS NULL e algum fogo_* preenchido).
--
-- Só o comentário da coluna é restaurável.

BEGIN;

DO $$
BEGIN
  RAISE EXCEPTION
    'mapbiomas_risco_carbono_nodata: a máscara de nodata é irreversível —
 os valores negativos foram descartados na origem (#154). Para reverter de
 verdade, reexecute a extração MapBiomasRisco das escolas afetadas (escolas
 com solo_carbono_medio IS NULL e algum fogo_* preenchido) e, só então,
 reverta esta change para repor o comentário da coluna.';
END $$;

COMMIT;
