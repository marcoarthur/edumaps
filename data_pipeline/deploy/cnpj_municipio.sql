-- Deploy edumaps:cnpj_municipio to pg
-- requires: transferencia_educ
--
-- #240: cache CNPJ -> município (IBGE) para atribuir ao município as
-- Unidades Executoras (UEx) do PDDE — caixas escolares, conselhos, APMs,
-- associações — que o arquivo da CGU traz só com o CNPJ, sem o código
-- SIAFI. A resolução prévia (SIAFI, de-para derivado das linhas de
-- prefeitura) deixava ~24,5 mil UEx órfãs; o CNPJ as resolve pela base
-- aberta da Receita Federal (cache para não repetir a consulta a cada
-- carga). Só CNPJs resolvidos entram; os não encontrados ficam em
-- cgu_orfaos.csv (sem cache negativo).

BEGIN;

-- =================================================================
-- CACHE CNPJ -> MUNICÍPIO
-- =================================================================
CREATE TABLE clean.cnpj_municipio (
    cnpj          CHAR(14) PRIMARY KEY,   -- só dígitos
    codigo_ibge   VARCHAR(7) NOT NULL,    -- município (IBGE) do CNPJ
    uf            CHAR(2),
    municipio     TEXT,                   -- nome devolvido pela fonte
    fonte         TEXT NOT NULL,          -- 'brasilapi' | 'minhareceita'
    atualizado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_cnpj_municipio_ibge ON clean.cnpj_municipio (codigo_ibge);

COMMENT ON TABLE clean.cnpj_municipio IS
'Cache CNPJ -> município (IBGE) para atribuir as UEx (caixas escolares, conselhos, APMs, associações) do PDDE (CGU) sem código SIAFI (#240). Fonte: dados abertos da Receita Federal via API BrasilAPI/Minha Receita; só CNPJs resolvidos entram (não há cache negativo). Populado pelo job CGU.';
COMMENT ON COLUMN clean.cnpj_municipio.cnpj IS
'CNPJ da UEx, só dígitos (14).';
COMMENT ON COLUMN clean.cnpj_municipio.codigo_ibge IS
'Código IBGE (7 dígitos) do município do endereço fiscal do CNPJ.';
COMMENT ON COLUMN clean.cnpj_municipio.fonte IS
'Fonte da resolução: brasilapi | minhareceita.';

-- O texto do PDDE na transferencia_educ passa a declarar a resolução por
-- CNPJ (o resto do COMMENT vem de comments_ingestao_p2).
COMMENT ON TABLE clean.transferencia_educ IS
'Transferências federais para educação (função 12) por município e mês — CGU Portal da Transparência, ZIP mensal oficial {AAAAMM}_Transferencias.zip (CC-BY-4.0). Prefeituras pelo CNPJ (SICONFI /entes) ou código SIAFI; PDDE às UEx agregado ao município pelo SIAFI (de-para derivado das linhas de prefeitura) ou pelo CNPJ da própria UEx (cache clean.cnpj_municipio; dados abertos da RFB). Estados e entidades fora do PDDE não entram; não resolvidos em cgu_orfaos.csv. Chave: codigo_ibge + programa + data_inicio + data_fim + dt_snapshot. Loader: job CGU (#238).';

COMMIT;
