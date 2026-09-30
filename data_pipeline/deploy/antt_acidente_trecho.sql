-- Deploy edumaps:antt_acidente_trecho to pg
-- requires: malha_municipio
-- requires: import_metadata_fase0

BEGIN;

-- =================================================================
-- ANTT - ACIDENTES EM RODOVIAS FEDERAIS POR TRECHO
-- Fonte: dados.antt.gov.br/dataset/acidentes + /dataset/trechos
-- CHAVE BRUTA: Concessionaria;Data;Km;Trecho — SEM MUNICÍPIO
-- JOIN OBRIGATÓRIO com trechos (geodados ANTT) para resolver trecho → município
-- =================================================================

DROP TABLE IF EXISTS clean.antt_acidente_trecho;
CREATE TABLE clean.antt_acidente_trecho (
    id_acidente           BIGSERIAL PRIMARY KEY,
    concessionaria        TEXT NOT NULL,
    data_acidente         DATE NOT NULL,
    km                    NUMERIC(10,3),
    trecho                TEXT NOT NULL,        -- código do trecho (chave para join com trechos)
    -- Dados do acidente
    tipo_acidente         TEXT,                 -- colisão, atropelamento, capotamento, etc.
    classificacao         TEXT,                 -- com vítima fatal, com vítima ferida, sem vítima
    causa_provavel        TEXT,
    condicao_tempo        TEXT,
    pista                 TEXT,                 -- simples, dupla, etc.
    -- Vítimas
    mortos                INTEGER DEFAULT 0,
    feridos_graves        INTEGER DEFAULT 0,
    feridos_leves         INTEGER DEFAULT 0,
    ilesos                INTEGER DEFAULT 0,
    -- Veículos envolvidos
    veiculos_envolvidos   INTEGER,
    -- Metadados
    dt_carga              TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT uq_antt_acidente UNIQUE (concessionaria, data_acidente, km, trecho)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_antt_acidente_data ON clean.antt_acidente_trecho (data_acidente);
CREATE INDEX IF NOT EXISTS idx_antt_acidente_trecho ON clean.antt_acidente_trecho (trecho);
CREATE INDEX IF NOT EXISTS idx_antt_acidente_concessionaria ON clean.antt_acidente_trecho (concessionaria);

-- Comentários
COMMENT ON TABLE clean.antt_acidente_trecho IS 'Acidentes ANTT por trecho rodoviário. CHAVE BRUTA não tem município — JOIN OBRIGATÓRIO com antt_trecho_geodados (trecho → município via geodados ANTT).';
COMMENT ON COLUMN clean.antt_acidente_trecho.concessionaria IS 'Concessionária da rodovia';
COMMENT ON COLUMN clean.antt_acidente_trecho.data_acidente IS 'Data do acidente';
COMMENT ON COLUMN clean.antt_acidente_trecho.km IS 'Quilômetro do acidente';
COMMENT ON COLUMN clean.antt_acidente_trecho.trecho IS 'Código do trecho (chave para join com geodados ANTT)';
COMMENT ON COLUMN clean.antt_acidente_trecho.tipo_acidente IS 'Tipo: colisão, atropelamento, capotamento, etc.';
COMMENT ON COLUMN clean.antt_acidente_trecho.classificacao IS 'Classificação: com vítima fatal, com vítima ferida, sem vítima';
COMMENT ON COLUMN clean.antt_acidente_trecho.mortos IS 'Quantidade de mortos';
COMMENT ON COLUMN clean.antt_acidente_trecho.feridos_graves IS 'Quantidade de feridos graves';
COMMENT ON COLUMN clean.antt_acidente_trecho.feridos_leves IS 'Quantidade de feridos leves';

-- Registro de metadados
INSERT INTO clean.import_metadata (table_name, source_file, source_url, source_license, retrieved_at, row_count_loaded, notes)
SELECT 'clean.antt_acidente_trecho'::text,
       'API ANTT acidentes + trechos'::text,
       'https://dados.antt.gov.br/dataset/acidentes'::text,
       'CC-BY-4.0 (ANTT)'::text,
       NOW(),
       COUNT(*)::bigint,
       'Importação via deploy Sqitch: antt_acidente_trecho. JOIN OBRIGATÓRIO com antt_trecho_geodados para resolver município.'
FROM clean.antt_acidente_trecho;

COMMIT;