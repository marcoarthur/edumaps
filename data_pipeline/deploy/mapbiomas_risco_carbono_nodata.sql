-- Deploy edumaps:mapbiomas_risco_carbono_nodata to pg
-- requires: mapbiomas_escola_risco
--
-- #278/#154: nodata do MapBiomas mascarado como NULL.
--
-- O raster de carbono do solo grava -3.4e38 em pixel sem dado e o R da
-- extração repassa o valor cru: na carga nacional (2026-10-19) ficaram
-- 690 de 156.816 buffers com solo_carbono_medio negativo (mín -211,05
-- tC/ha). Carbono negativo não existe — é artefato de nodata, e a regra
-- #154 diz: ausência vira NULL, nunca 0.
--
-- O loader já não repassa o valor (Job::MapBiomasRisco mascara < 0 antes
-- do COPY); esta change limpa o que já estava na tabela. O teto do
-- componente (p99 = 705,98 tC/ha, ivet-v1.2) foi calibrado SEM as linhas
-- negativas, portanto a máscara não move a 2ª medição nacional.

BEGIN;

UPDATE clean.mapbiomas_escola_risco
   SET solo_carbono_medio = NULL
 WHERE solo_carbono_medio < 0;

COMMENT ON COLUMN clean.mapbiomas_escola_risco.solo_carbono_medio IS
'Média do carbono total do solo no buffer (tC/ha). Nodata do raster (valor negativo, ex. -3.4e38) mascarado como NULL (#154) — o loader Job::MapBiomasRisco também filtra antes do COPY.';

COMMIT;
