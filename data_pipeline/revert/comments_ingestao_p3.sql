-- Revert edumaps:comments_ingestao_p3 from pg
--
-- Textos anteriores (lidos do banco de dev em 2026-10-14).

BEGIN;

COMMENT ON TABLE clean.mapbiomas_cobertura IS 'NÃO CONSTRUÍDA — #170: loader real aguarda e-SIC para token da API MapBiomas. O job antigo baixava malha municipal do IBGE (BR_Municipios_2024.gpkg), não MapBiomas — geometria administrativa não é uso do solo; defeito corrigido (job falha alto, vide issue). Seria: cobertura/uso do solo por município/ano/classe (collection9, 30m), areolizado sobre área de influência da escola.';
COMMENT ON COLUMN clean.mapbiomas_cobertura.colecao IS 'Coleção MapBiomas (ex.: collection9) — FIXAR, não interpolar ano';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe IS 'Código da classe MapBiomas (ex.: 3.1.1, 3.2, 4)';
COMMENT ON COLUMN clean.mapbiomas_cobertura.classe_desc IS 'Descrição legível da classe';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_ha IS 'Área em hectares';
COMMENT ON COLUMN clean.mapbiomas_cobertura.area_km2 IS 'Área em km² (area_ha / 100)';
COMMENT ON TABLE clean.cnes_estabelecimentos IS 'Estabelecimentos CNES sanitizados (sem PII). Apenas: codigo_cnes, codigo_municipio, codigo_tipo_unidade, status, lat/long, data_atualizacao, dt_snapshot. Sanitizado na ingestão: descartados nome_razao_social, nome_fantasia, CNPJ, telefone, e-mail, endereço/bairro.';
COMMENT ON COLUMN clean.cnes_estabelecimentos.status IS '1=Ativo, 0=Inativo';
COMMENT ON COLUMN clean.cnes_estabelecimentos.latitude IS 'Latitude (graus decimais)';
COMMENT ON COLUMN clean.cnes_estabelecimentos.longitude IS 'Longitude (graus decimais)';

COMMIT;
