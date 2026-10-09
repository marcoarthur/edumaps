-- Deploy edumaps:comments_inmet_mapbiomas_pendente to pg
-- requires: comments_esic_pendente
--
-- #171 (decisão C): a API do INMET foi retirada — não é URL errada nem
-- bloqueio de licença; os endpoints estão mortos (dados.inmet.gov.br sem
-- registo DNS, apitempo.inmet.gov.br/bdmep/estacao e /alertas/cap12 → 404,
-- restante host é interface web/feed RSS). Decisão C: sem loader para
-- endpoints mortos; as tabelas declaram NÃO CONSTRUÍDAS e ficam fora do
-- objetivo da #156.
--
-- #170 (parte 1): o job MapBiomas antigo baixava BR_Municipios_2024.gpkg
-- (malha municipal do IBGE) para uma tabela de uso do solo e descarregava
-- uma página web do MapBiomas — geometria administrativa não é cobertura de
-- uso do solo (mesmo defeito da #154). A API real exige token (e-SIC em
-- curso): o job falha alto e a tabela declara NÃO CONSTRUÍDA. O loader real
-- continua na #170.

BEGIN;

COMMENT ON TABLE clean.inmet_bdmep IS 'NÃO CONSTRUÍDA — decisão #171 (C): a API do INMET foi retirada (dados.inmet.gov.br não resolve; apitempo.inmet.gov.br/bdmep/estacao → 404). Job INMET.pm falha alto com o motivo; fora do objetivo da #156. Seria: série diária histórica de estações meteorológicas (BDMEP). Revisitar se o INMET publicar API/feed oficial.';

COMMENT ON TABLE clean.inmet_alerta IS 'NÃO CONSTRUÍDA — decisão #171 (C): a API Alerta-AS (CAP 1.2) do INMET foi retirada (dados.inmet.gov.br/alertas/cap12 → 404; o restante é interface web/feed RSS, que não alimenta esta tabela). Job INMET.pm falha alto com o motivo; fora do objetivo da #156. Seria: eventos meteorológicos que interrompem aula, por código IBGE.';

COMMENT ON TABLE clean.mapbiomas_cobertura IS 'NÃO CONSTRUÍDA — #170: loader real aguarda e-SIC para token da API MapBiomas. O job antigo baixava malha municipal do IBGE (BR_Municipios_2024.gpkg), não MapBiomas — geometria administrativa não é uso do solo; defeito corrigido (job falha alto, vide issue). Seria: cobertura/uso do solo por município/ano/classe (collection9, 30m), areolizado sobre área de influência da escola.';

COMMIT;
