-- Revert edumaps:cnpj_municipio from pg

BEGIN;

DROP TABLE IF EXISTS clean.cnpj_municipio;

-- Restaura o texto de transferencia_educ criado por comments_ingestao_p2.
COMMENT ON TABLE clean.transferencia_educ IS
'Transferências federais para educação (função 12) por município e mês — CGU Portal da Transparência, ZIP mensal oficial {AAAAMM}_Transferencias.zip (CC-BY-4.0). Prefeituras pelo CNPJ (SICONFI /entes) ou código SIAFI; PDDE às UEx agregado ao município pelo SIAFI (de-para derivado das linhas de prefeitura). Estados e entidades fora do PDDE não entram; não resolvidos em cgu_orfaos.csv. Chave: codigo_ibge + programa + data_inicio + data_fim + dt_snapshot. Loader: job CGU (#238).';

COMMIT;
