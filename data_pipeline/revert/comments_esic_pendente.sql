-- Revert edumaps:comments_esic_pendente from pg
-- Restaura os comments originais (estado anterior à #172).

BEGIN;

COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';

COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setor censitário IBGE 2022 (estrutura criada, dados a popular via geobr/ogr_fdw). 316.574 setores esperados, SRID 4674.';

COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-*. Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot.';

COMMIT;