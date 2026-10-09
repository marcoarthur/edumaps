-- =====================================================================
-- Backfill de proveniência — issue #157
--
-- Fecha a lacuna de auditoria de clean.import_metadata medida no produto
-- (database.edumaps) em 2026-10-09:
--
--   A. preenche proveniência dos 2 registros com source_url/licença/data NULL
--      (clean.inse, clean.censo_data_dictionary);
--   B. corrige a licença do BrazilCrime (GPL-3 -> MIT + file LICENSE, o que o
--      CRAN declara) e o source_url das isocronas (demo OSRM -> tileset
--      Geofabrik auto-hospedado);
--   C. registra as tabelas clean.* POPULADAS que nunca entraram no registry
--      (contagens medidas contra o produto) com proveniência das fichas em
--      docs/analises/fontes/;
--   D. registra as 3 views analíticas derivadas (esforco_fiscal_educacao,
--      mobilidade_escola, acessibilidade_saude).
--
-- IDEMPOTENTE: INSERT ... ON CONFLICT (table_name) DO UPDATE — pode rodar
-- quantas vezes. É dado, não schema: NÃO passa por Sqitch.
--
-- Rode contra a base-produto (database.edumaps) e contra o espelho local.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- A. Preencher os 2 registros com proveniência NULL
-- ---------------------------------------------------------------------
INSERT INTO clean.import_metadata
  (table_name, source_file, source_url, source_license, retrieved_at,
   row_count_loaded, notes)
VALUES
  ('clean.inse', 'inse_2023.csv',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/saeb',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 69756,
   'Microdados do SAEB/INSE 2023 (INEP). Contagem medida em 2026-10-09 contra a base produto; data de coleta original desconhecida (preenchido retroativo #157).'),
  ('clean.censo_data_dictionary', 'generated_from_catalog',
   'interno (gerado do catálogo PG — docs/diagramas/validacao)',
   'n/a (gerado internamente do catálogo; sem fonte externa)',
   now(), 765,
   'Dicionário gerado do catálogo do Postgres (ferramenta de validação em docs/diagramas/validacao), não de fonte externa. year_introduced preenchido 765/765; year_changed/year_deprecated nulos = primeira edição, sem mudança de código conhecida (#157 item 6).')
ON CONFLICT (table_name) DO UPDATE SET
  source_url      = EXCLUDED.source_url,
  source_license  = EXCLUDED.source_license,
  retrieved_at    = EXCLUDED.retrieved_at,
  row_count_loaded = EXCLUDED.row_count_loaded,
  notes           = EXCLUDED.notes;

-- ---------------------------------------------------------------------
-- B. Correções: BrazilCrime (licença) e isocronas (URL do tileset)
-- ---------------------------------------------------------------------
INSERT INTO clean.import_metadata
  (table_name, source_file, source_url, source_license, retrieved_at,
   row_count_loaded, notes)
VALUES
  ('clean.brazilcrime_municipio', 'Pacote R BrazilCrime (CRAN)',
   'https://cran.r-project.org/package=BrazilCrime',
   'MIT + file LICENSE (CRAN). Termos dos DADOS são do SINESP e não estão na página do CRAN — a confirmar (docs/analises/fontes/seguranca.md)',
   now(), 0,
   'Licença corrigida em 2026-10-09 (#157 item 3): o CRAN declara MIT + file LICENSE; o metadado antigo (GPL-3) estava errado.'),
  ('clean.isocrona_escolar', 'OSRM/Valhalla auto-hospedado (tileset Geofabrik Brazil)',
   'https://download.geofabrik.de/south-america/brazil.html',
   'BSD-2-Clause (OSRM) / MIT (Valhalla)',
   now(), 0,
   'source_url corrigido em 2026-10-09 (#157 item 4): apontava o servidor demo (router.project-osrm.org, sem SLA); o real é o tileset OSM Brasil (Geofabrik) extraído e auto-hospedado — data de build fixa (docs/analises/fontes/mobilidade.md).')
ON CONFLICT (table_name) DO UPDATE SET
  source_url      = EXCLUDED.source_url,
  source_license  = EXCLUDED.source_license,
  retrieved_at    = EXCLUDED.retrieved_at,
  notes           = EXCLUDED.notes;

-- ---------------------------------------------------------------------
-- C. Tabelas clean.* POPULADAS sem registro no import_metadata
--    (contagens medidas contra o produto em 2026-10-09)
-- ---------------------------------------------------------------------
INSERT INTO clean.import_metadata
  (table_name, source_file, source_url, source_license, retrieved_at,
   row_count_loaded, notes)
VALUES
  -- Educação — INEP (e-SIC pendente para a licença; trajeto real já carregado)
  ('clean.censo_escolas', 'microdados_censo_escolar_*.zip',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 214192, 'Censo Escolar (INEP) — carga real por outro caminho, não pelo job INEP (que é stub, #172).'),
  ('clean.censo_docentes', 'microdados_censo_escolar_*.zip',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 178772, 'Censo Escolar docentes (INEP).'),
  ('clean.censo_matriculas', 'microdados_censo_escolar_*.zip',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 178766, 'Censo Escolar matrículas (INEP).'),
  ('clean.censo_gestor', 'microdados_censo_escolar_*.zip',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 180540, 'Censo Escolar gestores (INEP).'),
  ('clean.ideb_notas_escolas', 'IDEB resultados (INEP)',
   'https://www.gov.br/inep/pt-br/areas-de-atuacao/pesquisas-estatisticas-e-indicadores/ideb/resultados',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 814448, 'IDEB por escola (INEP).'),
  ('clean.inep_notas_desagregadas', 'INEP notas desagregadas',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 384169, 'Notas desagregadas INEP (base IDEB/IVET).'),
  ('clean.inep', 'INEP (estrutura)',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados',
   'não verificada (e-SIC INEP pendente — docs/admin/esic-requests.md)',
   now(), 64905, 'Registros INEP (dimensão).'),

  -- Derivadas do pipeline (source_file segue o padrão "... (derivado)")
  ('clean.school_indicators', 'derivado de clean.censo_escolas',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (herda a licença da base INEP)',
   now(), 214192, 'Indicadores por escola derivados do Censo Escolar.'),
  ('clean.escolas', 'derivado (consolidação de clean.censo_escolas)',
   'https://www.gov.br/inep/pt-br/acesso-a-informacao/dados-abertos/microdados/censo-escolar',
   'não verificada (herda a licença da base INEP)',
   now(), 158182, 'Consolidação de escolas (derivado).'),
  ('clean.municipios_sp', 'derivado (malha municipal IBGE — SP)',
   'https://www.ibge.gov.br/geociencias/organizacao-territorial/malhas-territoriais.html',
   'uso livre com atribuição da fonte (IBGE)',
   now(), 5573, 'Municípios de SP (derivado; base das malhas SP).'),

  -- IBGE / SIDRA
  ('clean.dados_ibge', 'SIDRA API v3 (servicodados.ibge.gov.br)',
   'https://servicodados.ibge.gov.br/api/docs/agregados',
   'uso livre com atribuição da fonte (IBGE)',
   now(), 27850, 'Consolidação IBGE/SIDRA 5938 (formato largo, dados_ibge).'),
  ('clean.populacao_municipal', 'Censo IBGE (faixas etárias municipais)',
   'https://ftp.ibge.gov.br/Censo/',
   'uso livre com atribuição da fonte (IBGE)',
   now(), 5571, 'População municipal por faixa etária (Censo IBGE).'),

  -- SIOPE (FNDE) — folha de remuneração municipal
  ('clean.remuneracao_municipal', 'SIOPE (FNDE) — folha de remuneração municipal (bin/siope.pl)',
   'https://www.fnde.gov.br/siope/',
   'não verificada (dado público gov)',
   now(), 32581804, 'Remuneração municipal via SIOPE (FNDE) — bin/siope.pl; maior carga do produto (32,5M linhas).'),

  -- OSM / Overpass (ODbL)
  ('clean.osm_feature', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 103, 'Features OSM (POIs).'),
  ('clean.school_osm_feature', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 55, 'Features OSM por escola.'),
  ('clean.osm_landuse', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 48, 'Uso do solo OSM.'),
  ('clean.osm_query_feature', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 55, 'Features de queries OSM.'),
  ('clean.osm_query', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 3, 'Queries OSM persistidas.'),
  ('clean.school_osm_query', 'OSM Overpass API',
   'https://overpass-api.de/',
   'ODbL (Open Database License — dados OpenStreetMap)',
   now(), 2, 'Queries OSM por escola.')
ON CONFLICT (table_name) DO UPDATE SET
  source_url       = EXCLUDED.source_url,
  source_license   = EXCLUDED.source_license,
  retrieved_at     = EXCLUDED.retrieved_at,
  row_count_loaded = EXCLUDED.row_count_loaded,
  notes            = EXCLUDED.notes;

-- ---------------------------------------------------------------------
-- D. Views derivadas do pipeline (#157 item 5)
-- ---------------------------------------------------------------------
INSERT INTO clean.import_metadata
  (table_name, source_file, source_url, source_license, retrieved_at,
   row_count_loaded, notes)
VALUES
  ('analytics.esforco_fiscal_educacao', 'derivada (clean.siconfi_receita + clean.siconfi_despesa)',
   'https://servicodados.tesouro.gov.br/',
   'n/a (derivada interna; herda as licenças das bases SICONFI)',
   now(), NULL, 'View analítica derivada — linhas por consulta; colunas de esforço fiscal da educação.'),
  ('analytics.mobilidade_escola', 'derivada (clean.censo_escolas + fontes de mobilidade)',
   'n/a (derivada de múltiplas fontes — ver docs/analises/fontes/mobilidade.md)',
   'n/a (derivada interna)',
   now(), NULL, 'View analítica derivada — mobilidade por escola (isocronas, OD, frota).'),
  ('analytics.acessibilidade_saude', 'derivada (clean.censo_escolas + clean.cnes_estabelecimentos)',
   'n/a (derivada de múltiplas fontes — ver docs/analises/fontes/saude.md)',
   'n/a (derivada interna)',
   now(), NULL, 'View analítica derivada — acessibilidade a serviços de saúde por escola.')
ON CONFLICT (table_name) DO UPDATE SET
  source_file      = EXCLUDED.source_file,
  source_url       = EXCLUDED.source_url,
  source_license   = EXCLUDED.source_license,
  retrieved_at     = EXCLUDED.retrieved_at,
  notes            = EXCLUDED.notes;

COMMIT;