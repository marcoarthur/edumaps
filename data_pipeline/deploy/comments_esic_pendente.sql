-- Deploy edumaps:comments_esic_pendente to pg
-- requires: analytics_esforco_fiscal_fundeb
--
-- #172: o COMMENT das tabelas-fonte sem loader declara o estado honesto
-- (fonte NÃO carregada + motivo + tracker), em vez de silêncio. Um stub
-- que devolve sucesso é indistinguível de um job que correu e a fonte não
-- tinha nada — o comment é onde o porquê fica escrito.
--
-- As tabelas de aplicação (inventario_*, gestor, reunioes, chat...) ficam
-- de fora de propósito: são alimentadas pelo módulo gestor, não são alvos
-- de ingestão (o mapeamento da #172 que as associava ao FNDE estava errado).

BEGIN;

COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). NÃO CARREGADA — loader é stub à espera de e-SIC/licença do INEP (tracker: docs/admin/esic-requests.md). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';

COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setor censitário IBGE 2022 (estrutura criada, dados a popular via geobr/ogr_fdw). NÃO CARREGADA — loader pendente (IBGE/INEP; tracker: docs/admin/esic-requests.md). 316.574 setores esperados, SRID 4674.';

COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-*. Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot. NÃO CARREGADA — sem loader; a saúde exige allowlist de endpoints no data_pipeline antes (pendência Tech Lead, docs/personas/tech-lead.md).';

COMMIT;