-- Verify edumaps:censo_labels_consumers on pg
--
-- Gate (issue #160): as checagens levantam exceção. Além de a função e a view
-- existirem, conferimos que o rótulo `rede` da view casa com o dicionário — se
-- alguém trocar o dicionário sem rebuildar a view, isto falha.

BEGIN;

DO $$
DECLARE
    n integer;
    rec RECORD;
    v_label text;
BEGIN
    -- 1. typification_badge existe, devolve json e rotula pelo dicionário
    IF to_regprocedure('clean.typification_badge(bigint)') IS NULL THEN
        RAISE EXCEPTION 'censo_labels_consumers: clean.typification_badge(bigint) ausente';
    END IF;
    IF pg_get_function_result('clean.typification_badge(bigint)'::regprocedure) <> 'json' THEN
        RAISE EXCEPTION 'censo_labels_consumers: typification_badge não devolve json';
    END IF;

    SELECT co_entidade, tp_dependencia, tp_localizacao
      INTO rec
      FROM clean.censo_escolas
     WHERE tp_dependencia IS NOT NULL
     LIMIT 1;

    IF FOUND THEN
        v_label := (clean.typification_badge(rec.co_entidade) ->> 'label_principal');
        IF v_label IS DISTINCT FROM clean.censo_label('clean.censo_escolas', 'tp_dependencia', rec.tp_dependencia::text) THEN
            RAISE EXCEPTION 'censo_labels_consumers: label_principal (%) difere do dicionário', v_label;
        END IF;
    END IF;

    -- 2. a view materializada existe com as colunas usadas pelos consumidores
    -- (matview NÃO aparece em information_schema.columns — usar pg_attribute)
    IF to_regclass('analytics.mv_rede_escolas') IS NULL THEN
        RAISE EXCEPTION 'censo_labels_consumers: analytics.mv_rede_escolas ausente';
    END IF;
    SELECT count(*) INTO n
      FROM pg_attribute a
      JOIN pg_class c ON c.oid = a.attrelid
      JOIN pg_namespace ns ON ns.oid = c.relnamespace
     WHERE ns.nspname = 'analytics'
       AND c.relname = 'mv_rede_escolas'
       AND a.attnum > 0 AND NOT a.attisdropped
       AND a.attname IN ('co_municipio', 'codigo_rede', 'rede', 'total_escolas',
                         'total_etapas', 'media_etapas', 'total_matriculas', 'total_docentes');
    IF n <> 8 THEN
        RAISE EXCEPTION 'censo_labels_consumers: mv_rede_escolas com % de 8 colunas esperadas', n;
    END IF;

    -- 3. o rótulo `rede` da view é exatamente o do dicionário
    SELECT count(*) INTO n
      FROM analytics.mv_rede_escolas
     WHERE rede IS DISTINCT FROM
           LOWER(clean.censo_label('clean.censo_escolas', 'tp_dependencia', codigo_rede::text));
    IF n <> 0 THEN
        RAISE EXCEPTION 'censo_labels_consumers: % linhas de mv_rede_escolas com rede divergente do dicionário', n;
    END IF;

    -- 4. função de refresh presente
    IF to_regprocedure('analytics.refresh_rede_escolas()') IS NULL THEN
        RAISE EXCEPTION 'censo_labels_consumers: analytics.refresh_rede_escolas() ausente';
    END IF;
END $$;

ROLLBACK;
