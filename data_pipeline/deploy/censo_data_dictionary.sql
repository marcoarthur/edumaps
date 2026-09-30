-- Deploy edumaps:censo_data_dictionary to pg
-- requires: censo_escolar_2025
-- requires: censo_docentes
-- requires: matriculas_censo_2025
-- requires: censo_gestor
-- Note: depende da Fase 0 (#124) para source_url, source_license, retrieved_at
--       a migration popula esses campos se existirem (DO block dinâmico), senão ficam NULL

BEGIN;

-- =================================================================
-- TABELA CANÔNICA DE DICIONÁRIO DO CENSO ESCOLAR
-- =================================================================

CREATE TABLE IF NOT EXISTS clean.censo_data_dictionary (
    table_name           TEXT NOT NULL,
    column_name          TEXT NOT NULL,
    data_type            TEXT NOT NULL,
    description          TEXT,
    value_domain         JSONB,              -- {code: label} para enums (tp_*, in_*)
    year_introduced      SMALLINT NOT NULL,  -- primeira edição em que a coluna aparece
    year_changed         SMALLINT,           -- edição em que código/meaning mudou
    year_deprecated      SMALLINT,           -- edição em que foi removida/substituída
    is_pk                BOOLEAN DEFAULT FALSE,
    is_fk                BOOLEAN DEFAULT FALSE,
    fk_target_table      TEXT,               -- schema.table referenciada
    fk_target_column     TEXT,
    source_file          TEXT,               -- CSV de origem (de clean.import_metadata)
    source_url           TEXT,               -- URL de proveniência (de import_metadata_fase0)
    source_license       TEXT,               -- licença da fonte (de import_metadata_fase0)
    retrieved_at         TIMESTAMPTZ,        -- quando foi baixado (de import_metadata_fase0)
    notes                TEXT,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT censo_data_dictionary_pk
        PRIMARY KEY (table_name, column_name, year_introduced)
);

-- Índices para consultas comuns
CREATE INDEX IF NOT EXISTS idx_censo_dict_table
    ON clean.censo_data_dictionary (table_name);

CREATE INDEX IF NOT EXISTS idx_censo_dict_year
    ON clean.censo_data_dictionary (year_introduced);

CREATE INDEX IF NOT EXISTS idx_censo_dict_domain
    ON clean.censo_data_dictionary (table_name, column_name)
    WHERE value_domain IS NOT NULL;

-- Comentários da tabela
COMMENT ON TABLE clean.censo_data_dictionary IS
'Dicionário de dados canônico do Censo Escolar. Uma linha por (tabela, coluna, edição_introdução).
Versiona mudanças de código/significado entre edições (year_changed, year_deprecated).
Inclui domínio de valores (enums) e proveniência (source_url, source_license, retrieved_at).';

COMMENT ON COLUMN clean.censo_data_dictionary.table_name IS
'Nome qualificado da tabela (ex.: clean.censo_escolas)';

COMMENT ON COLUMN clean.censo_data_dictionary.column_name IS
'Nome da coluna na tabela';

COMMENT ON COLUMN clean.censo_data_dictionary.data_type IS
'Tipo de dado PostgreSQL (ex.: integer, varchar, smallint, numeric, date, boolean)';

COMMENT ON COLUMN clean.censo_data_dictionary.description IS
'Descrição em português do que a coluna representa (do COMMENT ON COLUMN do banco)';

COMMENT ON COLUMN clean.censo_data_dictionary.value_domain IS
'Domínio de valores para colunas categóricas (tp_*, in_*). JSONB: {codigo: "significado"}.
Ex.: {"1": "Federal", "2": "Estadual", "3": "Municipal", "4": "Privada"} para tp_dependencia.';

COMMENT ON COLUMN clean.censo_data_dictionary.year_introduced IS
'Ano da primeira edição do Censo em que esta coluna existe (ex.: 2025)';

COMMENT ON COLUMN clean.censo_data_dictionary.year_changed IS
'Ano em que o significado dos códigos mudou (ex.: 2018: código 3 deixou de ser "Estadual" e passou a "Municipal")';

COMMENT ON COLUMN clean.censo_data_dictionary.year_deprecated IS
'Ano em que a coluna foi removida ou substituída (NULL = ainda existe)';

COMMENT ON COLUMN clean.censo_data_dictionary.is_pk IS 'Chave primária da tabela origem';
COMMENT ON COLUMN clean.censo_data_dictionary.is_fk IS 'Chave estrangeira da tabela origem';
COMMENT ON COLUMN clean.censo_data_dictionary.fk_target_table IS 'Tabela referenciada (schema.table)';
COMMENT ON COLUMN clean.censo_data_dictionary.fk_target_column IS 'Coluna referenciada na tabela alvo';

COMMENT ON COLUMN clean.censo_data_dictionary.source_file IS
'Arquivo CSV de origem (de clean.import_metadata.source_file)';

COMMENT ON COLUMN clean.censo_data_dictionary.source_url IS
'URL de download dos microdados (de clean.import_metadata.source_url, Fase 0)';

COMMENT ON COLUMN clean.censo_data_dictionary.source_license IS
'Licença da fonte (de clean.import_metadata.source_license, Fase 0)';

COMMENT ON COLUMN clean.censo_data_dictionary.retrieved_at IS
'Timestamp de quando o arquivo foi baixado (de clean.import_metadata.retrieved_at, Fase 0)';

COMMENT ON COLUMN clean.censo_data_dictionary.notes IS
'Notas livres: ex.: "código 5 adicionado em 2022 para Educação do Campo"';

-- =================================================================
-- POPULAR A PARTIR DO CATÁLOGO DO BANCO + YAML CURADO
-- =================================================================

-- 1) Extrair metadados das tabelas censo_* do information_schema
WITH census_tables AS (
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'clean'
      AND table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
),
cols AS (
    SELECT
        c.table_name,
        c.column_name,
        c.data_type,
        col_description(format('%I.%I', c.table_schema, c.table_name)::regclass, c.ordinal_position) AS description,
        -- PK/FK info
        CASE WHEN pk.column_name IS NOT NULL THEN TRUE ELSE FALSE END AS is_pk,
        CASE WHEN fk.column_name IS NOT NULL THEN TRUE ELSE FALSE END AS is_fk,
        fk.foreign_table_name AS fk_target_table,
        fk.foreign_column_name AS fk_target_column
    FROM information_schema.columns c
    JOIN census_tables ct ON ct.table_name = c.table_name
    LEFT JOIN (
        SELECT kcu.table_name, kcu.column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = 'clean'
          AND tc.table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
    ) pk ON pk.table_name = c.table_name AND pk.column_name = c.column_name
    LEFT JOIN (
        SELECT
            kcu.table_name,
            kcu.column_name,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
         AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage ccu
          ON tc.constraint_name = ccu.constraint_name
         AND tc.table_schema = ccu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'clean'
          AND tc.table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
    ) fk ON fk.table_name = c.table_name AND fk.column_name = c.column_name
    WHERE c.table_schema = 'clean'
      AND c.table_name IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
),
-- 2) Importar source_file do import_metadata (já existe)
meta AS (
    SELECT
        im.table_name,
        im.source_file
    FROM clean.import_metadata im
    WHERE im.table_name IN (
        'clean.censo_escolas',
        'clean.censo_matriculas',
        'clean.censo_docentes',
        'clean.censo_gestor'
    )
),
-- 3) Domínios de valores (enums) extraídos do YAML curado + heurística tp_*/in_*
enum_domains AS (
    SELECT 'clean.censo_escolas' AS table_name, 'tp_dependencia' AS column_name,
           '{"1":"Federal","2":"Estadual","3":"Municipal","4":"Privada"}'::jsonb AS value_domain
    UNION ALL SELECT 'clean.censo_escolas', 'tp_categoria_escola_privada',
           '{"1":"Particular","2":"Comunitária","3":"Confessional","4":"Filantrópica"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_localizacao',
           '{"1":"Urbana","2":"Rural"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_localizacao_diferenciada',
           '{"1":"Assentamento","2":"Terra Indígena","3":"Quilombo","4":"Área remanescente de quilombos"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_situacao_funcionamento',
           '{"1":"Ativa","2":"Paralisada","3":"Extinta"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_aee',
           '{"1":"Sala multifuncional","2":"Outras salas","3":"Canto de atividades","4":"Itinerância","5":"Classe hospitalar","8":"Não se aplica"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_atividade_complementar',
           '{"1":"Meio período","2":"Período integral","3":"Ambas"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_itinerario_formativo',
           '{"1":"Linguagens","2":"Matemática","3":"Ciências da Natureza","4":"Ciências Humanas","5":"Técnico profissional"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_proposta_pedagogica',
           '{"1":"Própria","2":"Da rede","3":"Adaptada da rede"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_indigena_lingua',
           '{"1":"Indígena","2":"Português","3":"Ambas"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_ocupacao_predio_escolar',
           '{"1":"Próprio","2":"Alugado","3":"Cedido"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_ocupacao_galpao',
           '{"1":"Próprio","2":"Alugado","3":"Cedido"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_regulamentacao',
           '{"1":"Estadual","2":"Municipal","3":"Federal"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_poder_publico_parceria',
           '{"1":"Municipal","2":"Estadual","3":"Federal"}'::jsonb
    UNION ALL SELECT 'clean.censo_escolas', 'tp_rede_local',
           '{"0":"Inexistente","1":"Com fio","2":"WiFi","3":"Ambas"}'::jsonb
    UNION ALL SELECT 'clean.censo_matriculas', 'tp_dependencia',
           '{"1":"Federal","2":"Estadual","3":"Municipal","4":"Privada"}'::jsonb
    UNION ALL SELECT 'clean.censo_docentes', 'tp_dependencia',
           '{"1":"Federal","2":"Estadual","3":"Municipal","4":"Privada"}'::jsonb
    UNION ALL SELECT 'clean.censo_gestor', 'tp_dependencia',
           '{"1":"Federal","2":"Estadual","3":"Municipal","4":"Privada"}'::jsonb
    -- Colunas binárias in_* têm domínio implícito {0:"Não",1:"Sim"} - não listamos todas
)
INSERT INTO clean.censo_data_dictionary (
    table_name, column_name, data_type, description, value_domain,
    year_introduced, year_changed, year_deprecated,
    is_pk, is_fk, fk_target_table, fk_target_column,
    source_file, source_url, source_license, retrieved_at,
    notes
)
SELECT
    'clean.' || c.table_name AS table_name,
    c.column_name,
    c.data_type,
    c.description,
    ed.value_domain,
    2025 AS year_introduced,  -- primeira carga conhecida
    NULL::smallint AS year_changed,
    NULL::smallint AS year_deprecated,
    c.is_pk,
    c.is_fk,
    c.fk_target_table,
    c.fk_target_column,
    m.source_file,
    NULL::text AS source_url,      -- preenchido pelo DO block abaixo se Fase 0 existir
    NULL::text AS source_license,  -- preenchido pelo DO block abaixo se Fase 0 existir
    NULL::timestamptz AS retrieved_at, -- preenchido pelo DO block abaixo se Fase 0 existir
    CASE
        WHEN c.column_name LIKE 'tp_%' AND ed.value_domain IS NULL THEN 'Enum tp_* sem domínio no YAML — revisar'
        WHEN c.column_name LIKE 'in_%' THEN 'Binária 0/1 (implícito: 0=Não, 1=Sim)'
        ELSE NULL
    END AS notes
FROM cols c
LEFT JOIN meta m ON m.table_name = 'clean.' || c.table_name
LEFT JOIN enum_domains ed ON ed.table_name = 'clean.' || c.table_name AND ed.column_name = c.column_name
ON CONFLICT (table_name, column_name, year_introduced) DO NOTHING;

-- =================================================================
-- ATUALIZAR PROVENIÊNCIA (FASE 0) - DO BLOCK DINÂMICO
-- Só executa UPDATE se as colunas source_url, source_license, retrieved_at
-- existirem em clean.import_metadata
-- =================================================================

DO $$
DECLARE
    has_source_url boolean;
    has_source_license boolean;
    has_retrieved_at boolean;
    sql text;
    row_count integer;
BEGIN
    -- Verificar quais colunas existem
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'clean' AND table_name = 'import_metadata' AND column_name = 'source_url'
    ) INTO has_source_url;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'clean' AND table_name = 'import_metadata' AND column_name = 'source_license'
    ) INTO has_source_license;

    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'clean' AND table_name = 'import_metadata' AND column_name = 'retrieved_at'
    ) INTO has_retrieved_at;

    -- Se nenhuma coluna de Fase 0 existe, não faz nada
    IF NOT (has_source_url OR has_source_license OR has_retrieved_at) THEN
        RAISE NOTICE 'Fase 0 não detectada (colunas source_url/source_license/retrieved_at não existem). Proveniência mantida como NULL.';
        RETURN;
    END IF;

    -- Construir UPDATE dinâmico
    sql := 'UPDATE clean.censo_data_dictionary d SET ';

    IF has_source_url THEN
        sql := sql || 'source_url = im.source_url';
    END IF;

    IF has_source_license THEN
        IF has_source_url THEN sql := sql || ', '; END IF;
        sql := sql || 'source_license = im.source_license';
    END IF;

    IF has_retrieved_at THEN
        IF has_source_url OR has_source_license THEN sql := sql || ', '; END IF;
        sql := sql || 'retrieved_at = im.retrieved_at';
    END IF;

    sql := sql || '
        FROM clean.import_metadata im
        WHERE d.table_name = im.table_name
          AND im.table_name IN (
              ''clean.censo_escolas'',
              ''clean.censo_matriculas'',
              ''clean.censo_docentes'',
              ''clean.censo_gestor''
          )';

    EXECUTE sql;
    GET DIAGNOSTICS row_count = ROW_COUNT;
    RAISE NOTICE 'Proveniência (Fase 0) atualizada para % linhas', row_count;
END $$;

-- =================================================================
-- REGISTRO DA PRÓPRIA IMPORTAÇÃO DO DICIONÁRIO
-- =================================================================

INSERT INTO clean.import_metadata (table_name, source_file, row_count_loaded, notes)
SELECT 'clean.censo_data_dictionary',
       'generated_from_catalog',
       COUNT(*),
       'Dicionário gerado automaticamente do catálogo + YAML curado'
FROM clean.censo_data_dictionary;

COMMIT;