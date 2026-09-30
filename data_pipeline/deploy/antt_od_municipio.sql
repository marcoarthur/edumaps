-- Deploy edumaps:antt_od_municipio to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- ANTT MONITRIIP - MATRIZ OD MUNICÍPIO × MUNICÍPIO × MÊS
-- Fonte: dados.antt.gov.br/dataset/monitriip-servico-regular
-- Única matriz OD nacional com chave município-município, mensal desde jan/2019
-- Supressão OBRIGATÓRIA: quantidade_bilhetes < 10 ANTES de qualquer agregação
-- tipo_gratuidade FORA da camada analítica (indutor de reidentificação)
-- =================================================================

DROP TABLE IF EXISTS clean.antt_od_municipio;
CREATE TABLE clean.antt_od_municipio (
    codigo_ibge_origem    TEXT NOT NULL,      -- 7 dígitos IBGE (origem)
    codigo_ibge_destino   TEXT NOT NULL,      -- 7 dígitos IBGE (destino)
    mes_viagem            DATE NOT NULL,      -- primeiro dia do mês (ex.: 2019-01-01)
    quantidade_bilhetes   INTEGER,            -- quantidade de bilhetes (suprimido se < 10)
    supressao_aplicada    BOOLEAN DEFAULT FALSE, -- TRUE = valor suprimido (count < 10)
    -- Metadados
    dt_snapshot           DATE NOT NULL,      -- data do snapshot mensal

    CONSTRAINT pk_antt_od_municipio PRIMARY KEY (codigo_ibge_origem, codigo_ibge_destino, mes_viagem, dt_snapshot)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_od_origem ON clean.antt_od_municipio (codigo_ibge_origem);
CREATE INDEX IF NOT EXISTS idx_antt_od_destino ON clean.antt_od_municipio (codigo_ibge_destino);
CREATE INDEX IF NOT EXISTS idx_antt_od_mes ON clean.antt_od_municipio (mes_viagem);
CREATE INDEX IF NOT EXISTS idx_antt_od_dt_snapshot ON clean.antt_od_municipio (dt_snapshot);

-- FKs para malha_municipio
ALTER TABLE clean.antt_od_municipio
  ADD CONSTRAINT fk_antt_od_origem
  FOREIGN KEY (codigo_ibge_origem) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

ALTER TABLE clean.antt_od_municipio
  ADD CONSTRAINT fk_antt_od_destino
  FOREIGN KEY (codigo_ibge_destino) REFERENCES clean.malha_municipio(codigo_ibge)
  ON DELETE RESTRICT;

-- Comentários
COMMENT ON TABLE clean.antt_od_municipio IS 'ANTT MONITRIIP - Matriz OD município × município × mês (ônibus rodoviário intermunicipal). Supressão OBRIGATÓRIA: quantidade_bilhetes < 10 ANTES de qualquer agregação. tipo_gratuidade FORA da camada analítica. Série mensal desde jan/2019.';
COMMENT ON COLUMN clean.antt_od_municipio.codigo_ibge_origem IS 'Código IBGE do município de origem (7 dígitos)';
COMMENT ON COLUMN clean.antt_od_municipio.codigo_ibge_destino IS 'Código IBGE do município de destino (7 dígitos)';
COMMENT ON COLUMN clean.antt_od_municipio.mes_viagem IS 'Mês de referência (primeiro dia do mês)';
COMMENT ON COLUMN clean.antt_od_municipio.quantidade_bilhetes IS 'Quantidade de bilhetes (suprimido se < 10)';
COMMENT ON COLUMN clean.antt_od_municipio.supressao_aplicada IS 'TRUE = valor suprimido por supressão de célula pequena (count < 10)';
COMMENT ON COLUMN clean.antt_od_municipio.dt_snapshot IS 'Data do snapshot mensal (chave de versionamento)';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_od_municipio'::text,
       'API ANTT MONITRIIP'::text,
       'https://dados.antt.gov.br/dataset/monitriip-servico-regular'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_od_municipio. Supressão count < 10 obrigatória. tipo_gratuidade excluído. CSV ISO-8859-1, delimitador ;.'
FROM clean.antt_od_municipio;

COMMIT;