-- Revert edumaps:import_metadata_fontes_p0 from pg
--
-- Restaura os COMMENTs da comments_esic_pendente, as source_url antigas
-- (mortas — é o estado anterior, não uma recomendação) e limpa o estado
-- 'nao_carregada' declarado por esta change (só onde ele ainda é o desta
-- change, identificado pela marca no motivo).

BEGIN;

COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). NÃO CARREGADA — loader é stub à espera de e-SIC/licença do INEP (tracker: docs/admin/esic-requests.md). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';

COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setor censitário IBGE 2022 (estrutura criada, dados a popular via geobr/ogr_fdw). NÃO CARREGADA — loader pendente (IBGE/INEP; tracker: docs/admin/esic-requests.md). 316.574 setores esperados, SRID 4674.';

COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-*. Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot. NÃO CARREGADA — sem loader; a saúde exige allowlist de endpoints no data_pipeline antes (pendência Tech Lead, docs/personas/tech-lead.md).';

UPDATE clean.import_metadata
   SET source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.gpkg'
 WHERE table_name = 'clean.malha_municipio'
   AND source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.zip';

UPDATE clean.import_metadata
   SET source_url  = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_setores_censitarios/setor_censitario_2022/Brasil/BR_Setor_Censitario_2022.gpkg',
       source_file = 'BR_Setor_Censitario_2022.gpkg (IBGE Geoftp)'
 WHERE table_name = 'clean.malha_setor_censitario'
   AND source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/gpkg/BR/BR_setores_CD2022.gpkg';

UPDATE clean.import_metadata
   SET source_url = 'https://geoftp.ibge.gov.br/recenseamento_2022/'
 WHERE table_name = 'clean.censo2022_setor'
   AND source_url = 'https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/';

UPDATE clean.import_metadata
   SET source_url  = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_rodoviaria',
       source_file = 'INDE DNIT SNV + VMDA'
 WHERE table_name = 'clean.snv_trecho_vmda'
   AND source_url = 'https://ide.geobases.es.gov.br/layers/geonode:dnit_vmda_modelagem_2022_es_utf8_epsg_31984';

UPDATE clean.import_metadata
   SET ultimo_status = NULL,
       ultimo_motivo = NULL
 WHERE ultimo_status = 'nao_carregada'
   AND ultimo_motivo LIKE '%[declarado pela change import_metadata_fontes_p0]';

COMMIT;
