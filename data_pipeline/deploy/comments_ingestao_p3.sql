-- Deploy edumaps:comments_ingestao_p3 to pg
-- requires: mapbiomas_cobertura
-- requires: cnes_estabelecimentos
-- requires: comments_inmet_mapbiomas_pendente
-- requires: comments_ingestao_p2
--
-- #241 (P3 da #156): os loaders existem. MapBiomas deixa de ser "NÃO
-- CONSTRUÍDA" (estatística oficial da Coleção 10) e o CNES declara o recorte
-- (só ativos), a sanitização e a decisão de licença.

BEGIN;

COMMENT ON TABLE clean.mapbiomas_cobertura IS
'Cobertura e uso da terra por município × classe × ano — estatística OFICIAL do MapBiomas, Coleção 10 (MAPBIOMAS_BRAZIL-COL.10-BIOME_STATE_MUNICIPALITY.xlsx, bucket público mapbiomas-public, CC-BY-4.0). Biomas somados por município; anos carregados 2015–2024 (decisão #241). Geocode fora da malha_municipio vai para mapbiomas_orfaos.csv. Loader: job MapBiomas (#241).';
COMMENT ON COLUMN clean.mapbiomas_cobertura.colecao IS
'Coleção MapBiomas da estatística (collection10). A Coleção 11 entra quando o MapBiomas publicar a estatística municipal dela.';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe IS
'Código numérico da legenda da Coleção 10 (classe-folha; 0 = Not Observed).';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe_desc IS
'Nome do nível mais específico da legenda (class_level_4), em inglês, como na planilha.';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_ha IS
'Área em hectares (unidade declarada no READ_ME da planilha), somada sobre os biomas do município.';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_km2 IS
'area_ha / 100.';

COMMENT ON TABLE clean.cnes_estabelecimentos IS
'Estabelecimentos de saúde ATIVOS do CNES (API apidadosabertos.saude.gov.br/cnes/estabelecimentos, status=1), SANITIZADOS na ingestão: só código CNES, município (IBGE 7), tipo de unidade, lat/long e data de atualização — razão social, nome fantasia, CNPJ, telefone, e-mail e endereço descartados (o bruto preservado também é o sanitizado). Licença CC BY-ND 3.0: subconjunto de colunas sem alteração de valores (não é obra derivada; decisão #241). Chave: codigo_cnes + dt_snapshot. Loader: job CNES (#241).';
COMMENT ON COLUMN clean.cnes_estabelecimentos.status IS
'Sempre 1: só estabelecimentos ativos são consultados (status=1 na API, decisão #241); desabilitados não entram.';
COMMENT ON COLUMN clean.cnes_estabelecimentos.latitude IS
'Como publicada (graus decimais); NULL quando ausente, zero, incompleta ou fora da caixa do Brasil (contadas no import_metadata).';
COMMENT ON COLUMN clean.cnes_estabelecimentos.longitude IS
'Como publicada (graus decimais); NULL quando ausente, zero, incompleta ou fora da caixa do Brasil (contadas no import_metadata).';

COMMIT;
