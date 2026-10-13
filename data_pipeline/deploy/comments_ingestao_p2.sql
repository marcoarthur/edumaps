-- Deploy edumaps:comments_ingestao_p2 to pg
-- requires: transferencia_educ
-- requires: malha_setor_censitario
-- requires: censo2022_setor
-- requires: sisab_aps
-- requires: import_metadata_fontes_p0
--
-- #238 (P2 da #156): os loaders existem. Os COMMENTs deixam de dizer
-- "NÃO CARREGADA" e passam a declarar a fonte real, o que fica NULL por
-- desenho (sem fonte) e as unidades medidas na API.
-- Mantém "IBGE"/"DOMÍNIO PÚBLICO" (setores) e "datasus_sisab" (SISAB):
-- o verify de import_metadata_fontes_p0 continua a exigi-los.

BEGIN;

COMMENT ON TABLE clean.transferencia_educ IS
'Transferências federais para educação (função 12) por município e mês — CGU Portal da Transparência, ZIP mensal oficial {AAAAMM}_Transferencias.zip (CC-BY-4.0). Prefeituras pelo CNPJ (SICONFI /entes) ou código SIAFI; PDDE às UEx agregado ao município pelo SIAFI (de-para derivado das linhas de prefeitura). Estados e entidades fora do PDDE não entram; não resolvidos em cgu_orfaos.csv. Chave: codigo_ibge + programa + data_inicio + data_fim + dt_snapshot. Loader: job CGU (#238).';
COMMENT ON COLUMN clean.transferencia_educ.programa IS
'Ação orçamentária: 00SB=FUNDEB (complementação da União), 0969=PNATE, 0E53=CAMINHO_DA_ESCOLA, 0515=PDDE, 12KU/00SU=PROINFANCIA, 20RP=INFRAESTRUTURA_EDUC_BASICA, 0509=APOIO_EDUC_BASICA, 00PI=PNAE, 00OW=MANUTENCAO_EDUC_INFANTIL; outras ações de educação = ACAO_<código>.';
COMMENT ON COLUMN clean.transferencia_educ.valor_transferido IS
'Soma do VALOR TRANSFERIDO no mês (R$), estornos negativos incluídos.';
COMMENT ON COLUMN clean.transferencia_educ.data_inicio IS
'Primeiro dia do mês de referência (ANO / MÊS).';
COMMENT ON COLUMN clean.transferencia_educ.data_fim IS
'Último dia do mês de referência (ANO / MÊS).';

COMMENT ON TABLE clean.malha_setor_censitario IS
'Malha de setores do Censo 2022, IBGE (BR_setores_CD2022.gpkg, geoftp.ibge.gov.br), SIRGAS 2000/EPSG 4674 — DOMÍNIO PÚBLICO. Carregada pelo job SetoresCenso2022 (#238): geometrias inválidas reparadas com ST_MakeValid; setores de município ausente da malha_municipio ficam de fora (contados no import_metadata).';

COMMENT ON TABLE clean.censo2022_setor IS
'Censo Demográfico 2022 por setor (Agregados por Setores Censitários, IBGE FTP — DOMÍNIO PÚBLICO), temas básico, demografia e cor/raça. Carregada pelo job SetoresCenso2022 (#238). Célula ''X'' do IBGE = NULL com supressao_celula_pequena = true (vazio ≠ zero). Colunas sem fonte por setor (esc_*, rend_*, cor_sem_decl) ficam NULL por desenho.';
COMMENT ON COLUMN clean.censo2022_setor.esc_sem_instrucao IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_incomp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_fund_comp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_incomp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_med_comp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_incomp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.esc_sup_comp IS
'Sem fonte no Censo 2022 por setor: os Agregados por Setores publicam alfabetização, não nível de instrução. NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.rend_media IS
'Sem fonte nos Agregados por Setores do Censo 2022 (rendimento não publicado por setor). NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.rend_per_capita IS
'Sem fonte nos Agregados por Setores do Censo 2022 (rendimento não publicado por setor). NULL por desenho (#238).';
COMMENT ON COLUMN clean.censo2022_setor.cor_sem_decl IS
'Sem fonte: o tema Cor ou Raça por setor (V01317–V01321) não tem categoria ''sem declaração''. NULL por desenho (#238).';

COMMENT ON TABLE clean.sisab_aps IS
'Consolidado ATUAL do PMMB (Programa Mais Médicos) por município, da API apidadosabertos.saude.gov.br/atencao-primaria/pmmb-consolidado (allowlist datasus_sisab) — não é a série do SISAB nem a cobertura APS total. Só nível MUNICIPAL (DSEI/estaduais descartados). Sem histórico na fonte: a série acumula a cada execução (dt_snapshot). Chave: codigo_municipio (IBGE 7) + dt_referencia + dt_snapshot. Loader: job SISAB (#238).';
COMMENT ON COLUMN clean.sisab_aps.cobertura_aps IS
'População coberta estimada pelas equipes do PMMB (pessoas), como publicada em pmmb-consolidado.cobertura — NÃO é percentual.';
COMMENT ON COLUMN clean.sisab_aps.dt_referencia IS
'Primeiro dia do mês da geração do consolidado na API (a data exata fica no import_metadata.notes).';

COMMIT;
