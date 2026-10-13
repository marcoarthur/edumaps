-- Revert edumaps:comments_ingestao_p2 from pg
--
-- Textos anteriores (lidos do banco de dev em 2026-10-13).

BEGIN;

COMMENT ON TABLE clean.transferencia_educ IS 'Transferências da União para educação (CGU Portal da Transparência). WAF intermitente (405 Human Verification) → retry com backoff obrigatório. Chave: codigo_ibge + programa + data_inicio + data_fim + dt_snapshot. Programas: FUNDEB, PNATE, PROINFANCIA, PDDE, etc.';
COMMENT ON COLUMN clean.transferencia_educ.programa IS 'Programa federal (FUNDEB, PNATE, PROINFANCIA, PDDE, etc.)';
COMMENT ON COLUMN clean.transferencia_educ.valor_transferido IS 'Valor transferido (reais)';
COMMENT ON COLUMN clean.transferencia_educ.data_inicio IS 'Início do período de transferência';
COMMENT ON COLUMN clean.transferencia_educ.data_fim IS 'Fim do período de transferência';
COMMENT ON TABLE clean.malha_setor_censitario IS 'Malha de setores censitários do Censo 2022, IBGE (BR_setores_CD2022.gpkg, ~1,49 GB, geoftp.ibge.gov.br) — DOMÍNIO PÚBLICO, não depende de e-SIC. NÃO CARREGADA — loader pendente (fase P2 da #156). 316.574 setores esperados, SRID 4674.';
COMMENT ON TABLE clean.censo2022_setor IS 'Censo Demográfico 2022 por setor censitário (~316k setores, ~3000 variáveis). Fonte: IBGE, Agregados por Setores Censitários (https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/) — DOMÍNIO PÚBLICO, não depende de e-SIC. NÃO CARREGADA — loader pendente (fase P2 da #156). Vazio ≠ zero: supressao_celula_pequena=true indica supressão estatística, não valor zero.';
COMMENT ON COLUMN clean.censo2022_setor.esc_sem_instrucao IS 'Pessoas 25+ anos sem instrução';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_incomp IS 'Pessoas 25+ anos com fundamental incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_comp IS 'Pessoas 25+ anos com fundamental completo';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_incomp IS 'Pessoas 25+ anos com médio incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_comp IS 'Pessoas 25+ anos com médio completo';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_incomp IS 'Pessoas 25+ anos com superior incompleto';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_comp IS 'Pessoas 25+ anos com superior completo';
COMMENT ON COLUMN clean.censo2022_setor.rend_media IS NULL;
COMMENT ON COLUMN clean.censo2022_setor.rend_per_capita IS 'Rendimento médio per capita (reais)';
COMMENT ON COLUMN clean.censo2022_setor.cor_sem_decl IS 'Cor/raça sem declaração';
COMMENT ON TABLE clean.sisab_aps IS 'Indicadores APS (SISAB/PIMMB) agregados por município/mês. Fonte: apidadosabertos.saude.gov.br/atencao-primaria/pmmb-* (endpoints já no allowlist: data_pipeline/allowlist.yaml, entrada datasus_sisab). Chave: codigo_municipio (IBGE 7 dígitos) + dt_referencia + dt_snapshot. NÃO CARREGADA — sem loader ainda (fase P2 da #156).';
COMMENT ON COLUMN clean.sisab_aps.cobertura_aps IS 'Cobertura APS (%)';
COMMENT ON COLUMN clean.sisab_aps.dt_referencia IS 'Mês de referência (primeiro dia do mês)';

COMMIT;
