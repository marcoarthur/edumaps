-- Deploy edumaps:import_metadata_fontes_p0 to pg
-- requires: import_metadata_estado
-- requires: comments_inmet_mapbiomas_pendente
--
-- =================================================================
-- #231 (P0 da #156): comments errados, source_url mortas e estado
-- 'nao_carregada' das fontes fora do objetivo.
--
-- 1. COMMENTs (sobrescrevem os da comments_esic_pendente, #172):
--    - malha_setor_censitario e censo2022_setor diziam "e-SIC/licença do
--      INEP": são do IBGE, domínio público, e não dependem de e-SIC;
--    - sisab_aps dizia "exige allowlist antes": a entrada datasus_sisab já
--      existe no data_pipeline/allowlist.yaml.
-- 2. source_url mortas em clean.import_metadata (HEAD a partir de
--    backend.edumaps em 2026-10-13):
--    - malha_municipio: .../BR_Municipios_2024.gpkg -> 404; o .zip -> 200;
--    - malha_setor_censitario: .../malha_setores_censitarios/.../
--      BR_Setor_Censitario_2022.gpkg -> 404; o vivo é
--      .../malhas_de_setores_censitarios__divisoes_intramunicipais/
--      censo_2022/setores/gpkg/BR/BR_setores_CD2022.gpkg (200, 1,49 GB);
--    - censo2022_setor: geoftp.../recenseamento_2022/ -> 404; o vivo é
--      ftp.ibge.gov.br/Censos/Censo_Demografico_2022/
--      Agregados_por_Setores_Censitarios/ (200);
--    - snv_trecho_vmda apontava para o IBGE (geoftp .../malha_rodoviaria,
--      404); a camada VMDA é do DNIT, e o único espelho publicado é o
--      GeoNode do ES (docs/analises/fontes/mobilidade.md) — 200.
--    Cada UPDATE só troca se ainda estiver a URL morta: não pisa numa carga
--    real que tenha gravado outra URL.
-- 3. Estado 'nao_carregada' declarado por DECISÃO (ultima_tentativa_em fica
--    NULL: não houve tentativa), só onde ainda não há estado:
--    - ANTT (4 tabelas): host fora do ar, fora do objetivo por ora;
--    - isocrona_escolar: infraestrutura nova, fora do objetivo por ora;
--    - inmet_bdmep / inmet_alerta: API retirada (#171, decisão C).
--    e-SICs NÃO PROTOCOLADOS (decisão de 2026-10-13): nenhuma tabela do
--    import_metadata depende só deles — FNDE, Medidor e Secretarias não têm
--    tabela clean.* própria, e as do Censo Escolar já foram carregadas por
--    outro caminho. O estado deles fica nos jobs (exit 3, ver CLI.pm).
-- =================================================================

BEGIN;

-- 1. COMMENTs -------------------------------------------------------

COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). Fonte: IBGE, Agregados por Setores Censitários (https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/) — DOMÍNIO PÚBLICO, não depende de e-SIC. NÃO CARREGADA — loader pendente (fase P2 da #156). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';

COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setores censitários do Censo 2022, IBGE (BR_setores_CD2022.gpkg, ~1,49 GB, geoftp.ibge.gov.br) — DOMÍNIO PÚBLICO, não depende de e-SIC. NÃO CARREGADA — loader pendente (fase P2 da #156). 316.574 setores esperados, SRID 4674.';

COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-* (endpoints já no allowlist: data_pipeline/allowlist.yaml, entrada datasus_sisab). Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot. NÃO CARREGADA — sem loader ainda (fase P2 da #156).';

-- 2. source_url mortas ----------------------------------------------

UPDATE clean.import_metadata
   SET source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.zip'
 WHERE table_name = 'clean.malha_municipio'
   AND source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.gpkg';

UPDATE clean.import_metadata
   SET source_url  = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/gpkg/BR/BR_setores_CD2022.gpkg',
       source_file = 'BR_setores_CD2022.gpkg (IBGE geoftp)'
 WHERE table_name = 'clean.malha_setor_censitario'
   AND source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_setores_censitarios/setor_censitario_2022/Brasil/BR_Setor_Censitario_2022.gpkg';

UPDATE clean.import_metadata
   SET source_url = 'https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/'
 WHERE table_name = 'clean.censo2022_setor'
   AND source_url = 'https://geoftp.ibge.gov.br/recenseamento_2022/';

UPDATE clean.import_metadata
   SET source_url  = 'https://ide.geobases.es.gov.br/layers/geonode:dnit_vmda_modelagem_2022_es_utf8_epsg_31984',
       source_file = 'DNIT VMDA modelagem 2022 (espelho INDE no GeoNode do ES)'
 WHERE table_name = 'clean.snv_trecho_vmda'
   AND source_url = 'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_rodoviaria';

-- 3. nao_carregada por decisão -------------------------------------

UPDATE clean.import_metadata
   SET ultimo_status = 'nao_carregada',
       ultimo_motivo = 'Fora do objetivo por ora (decisão do developer de 2026-10-13, plano da #156 §6): host dados.antt.gov.br fora do ar; o job ANTT tem de ser reescrito. Volta em issue própria. [declarado pela change import_metadata_fontes_p0]'
 WHERE table_name IN ('clean.antt_od_municipio', 'clean.antt_acidente_trecho',
                      'clean.antt_trecho_geodados', 'clean.antt_contagem_equipamento')
   AND ultimo_status IS NULL;

UPDATE clean.import_metadata
   SET ultimo_status = 'nao_carregada',
       ultimo_motivo = 'Fora do objetivo por ora (decisão do developer de 2026-10-13, plano da #156 §6): exige infraestrutura nova (OSRM/Valhalla auto-hospedado, PBF de 2,1 GB, H3). Volta em issue própria. [declarado pela change import_metadata_fontes_p0]'
 WHERE table_name = 'clean.isocrona_escolar'
   AND ultimo_status IS NULL;

UPDATE clean.import_metadata
   SET ultimo_status = 'nao_carregada',
       ultimo_motivo = 'NÃO CONSTRUÍDA — decisão #171 (C): a API do INMET foi retirada (endpoints mortos); fora do objetivo da #156. [declarado pela change import_metadata_fontes_p0]'
 WHERE table_name IN ('clean.inmet_bdmep', 'clean.inmet_alerta')
   AND ultimo_status IS NULL;

COMMIT;
