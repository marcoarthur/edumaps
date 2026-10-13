-- Revert edumaps:censo_data_dictionary_inep from pg
--
-- Volta o dicionário ao estado da change censo_data_dictionary: remove a
-- função de violações e a coluna `origem`, apaga as linhas das 4 tabelas do
-- Censo e refaz o seed original (catálogo + domínios curados, year_introduced
-- = 2025). O bloco abaixo é cópia literal do seed de deploy/censo_data_dictionary.sql.

BEGIN;

DROP FUNCTION IF EXISTS clean.censo_dict_violacoes();

DELETE FROM clean.censo_data_dictionary
WHERE table_name IN ('clean.censo_escolas', 'clean.censo_matriculas',
                     'clean.censo_docentes', 'clean.censo_gestor');

ALTER TABLE clean.censo_data_dictionary DROP COLUMN IF EXISTS origem;

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
UPDATE clean.import_metadata
SET notes = 'Dicionário gerado automaticamente do catálogo + YAML curado'
WHERE table_name = 'clean.censo_data_dictionary';

COMMIT;
