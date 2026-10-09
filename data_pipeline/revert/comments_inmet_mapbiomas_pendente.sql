-- Revert edumaps:comments_inmet_mapbiomas_pendente from pg
-- Restaura os comments originais (estado anterior a #171/#170).

BEGIN;

COMMENT ON TABLE clean.inmet_bdmep IS 'INMET BDMEP - série diária histórica de estações meteorológicas (26 anos). API sem autenticação. Base para normalização climática.';

COMMENT ON TABLE clean.inmet_alerta IS 'INMET Alerta-AS (CAP 1.2) - eventos meteorológicos que interrompem aula. Cada linha é um evento com código IBGE do município afetado. Mede o EVENTO, não a exposição.';

COMMENT ON TABLE clean.mapbiomas_cobertura IS 'MapBiomas cobertura/uso do solo por município/ano/classe. Fonte: collection fixa (ex.: collection9). Granularidade 30m. Arealizar sobre área de influência da escola, não sobre centroide.';

COMMIT;
