-- Deploy edumaps:transferencia_educ to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- CGU PORTAL DA TRANSPARÊNCIA - TRANSFERÊNCIAS DA UNIÃO (EDUCAÇÃO)
-- Fonte: api.portaldatransparencia.gov.br/api-de-dados/transferencias
-- WAF intermitente (405 "Human Verification") → retry com backoff obrigatório
-- Chave: codigo_ibge + data_inicio + data_fim + programa
-- =================================================================

DROP TABLE IF EXISTS clean.transferencia_educ;
CREATE TABLE clean.transferencia_educ (
    codigo_ibge       TEXT NOT NULL,      -- 7 dígitos IBGE
    nome_municipio    TEXT,               -- nome do município
    programa          TEXT NOT NULL,      -- ex.: 'FUNDEB', 'PNATE', 'PROINFANCIA', 'PDDE'
    valor_transferido NUMERIC NOT NULL,   -- valor transferido (reais)
    data_inicio       DATE NOT NULL,      -- início do período
    data_fim          DATE NOT NULL,      -- fim do período
    -- Metadados
    dt_snapshot       DATE NOT NULL,      -- data do snapshot (data da consulta)

    CONSTRAINT pk_transferencia_educ PRIMARY KEY (codigo_ibge, programa, data_inicio, data_fim, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_transferencia_educ_codigo_ibge ON clean.transferencia_educ (codigo_ibge);
CREATE INDEX IF NOT EXISTS idx_transferencia_educ_programa ON clean.transferencia_educ (programa);
CREATE INDEX IF NOT EXISTS idx_transferencia_educ_data ON clean.transferencia_educ (data_inicio, data_fim);
CREATE INDEX IF NOT EXISTS idx_transferencia_educ_dt_snapshot ON clean.transferencia_educ (dt_snapshot);

-- FK para malha_municipio
ALTER TABLE clean.transferencia_educ
  ADD CONSTRAINT fk_transferencia_educ_municipio
  FOREIGN KEY (codigo_ibge) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.transferencia_educ IS 'Transferências da União para educação (CGU Portal da Transparência). WAF intermitente (405 Human Verification) → retry com backoff obrigatório. Chave: codigo_ibge + programa + data_inicio + data_fim + dt_snapshot. Programas: FUNDEB, PNATE, PROINFANCIA, PDDE, etc.';
COMMENT ON COLUMN clean.transferencia_educ.codigo_ibge IS 'Código IBGE do município (7 dígitos)';
COMMENT ON COLUMN clean.transferencia_educ.nome_municipio IS 'Nome do município';
COMMENT ON COLUMN clean.transferencia_educ.programa IS 'Programa federal (FUNDEB, PNATE, PROINFANCIA, PDDE, etc.)';
COMMENT ON COLUMN clean.transferencia_educ.valor_transferido IS 'Valor transferido (reais)';
COMMENT ON COLUMN clean.transferencia_educ.data_inicio IS 'Início do período de transferência';
COMMENT ON COLUMN clean.transferencia_educ.data_fim IS 'Fim do período de transferência';
COMMENT ON COLUMN clean.transferencia_educ.dt_snapshot IS 'Data da consulta (snapshot)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.transferencia_educ'::text,
       'API CGU Portal da Transparência transferências'::text,
       'https://api.portaldatransparencia.gov.br/api-de-dados/transferencias'::text,
       'CC-BY-4.0 (CGU)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: transferencia_educ. WAF intermitente (405) → retry com backoff. Job noturno com cache.'
FROM clean.transferencia_educ;

COMMIT;