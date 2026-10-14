-- Verify edumaps:censo_label on pg
--
-- Gate (issue #160): cada checagem levanta exceção. O helper tem de ler o
-- dicionário canônico, não um mapa próprio — por isso conferimos os valores
-- contra `value_domain` e não só contra literais.

BEGIN;

DO $$
DECLARE
    v text;
    n integer;
BEGIN
    IF to_regprocedure('clean.censo_labels(text,text)') IS NULL
       OR to_regprocedure('clean.censo_label(text,text,text)') IS NULL
       OR to_regprocedure('clean.censo_code(text,text,text)') IS NULL THEN
        RAISE EXCEPTION 'censo_label: helper incompleto (censo_labels/censo_label/censo_code)';
    END IF;

    -- código -> rótulo
    IF clean.censo_label('clean.censo_escolas', 'tp_dependencia', '1') <> 'Federal' THEN
        RAISE EXCEPTION 'censo_label: tp_dependencia 1 <> Federal';
    END IF;
    IF clean.censo_label('clean.censo_escolas', 'tp_dependencia', '3') <> 'Municipal' THEN
        RAISE EXCEPTION 'censo_label: tp_dependencia 3 <> Municipal';
    END IF;
    IF clean.censo_label('clean.censo_escolas', 'tp_localizacao', '1') <> 'Urbana' THEN
        RAISE EXCEPTION 'censo_label: tp_localizacao 1 <> Urbana';
    END IF;
    IF clean.censo_label('clean.censo_escolas', 'tp_dependencia', '99') IS NOT NULL THEN
        RAISE EXCEPTION 'censo_label: código desconhecido deveria devolver NULL';
    END IF;

    -- rótulo -> código (case-insensitive)
    IF clean.censo_code('clean.censo_escolas', 'tp_localizacao', 'rural') <> '2' THEN
        RAISE EXCEPTION 'censo_code: ''rural'' <> 2';
    END IF;
    IF clean.censo_code('clean.censo_escolas', 'tp_dependencia', 'FEDERAL') <> '1' THEN
        RAISE EXCEPTION 'censo_code: ''FEDERAL'' <> 1';
    END IF;

    -- o domínio casa exatamente com o value_domain do dicionário
    SELECT count(*) INTO n
    FROM clean.censo_labels('clean.censo_escolas', 'tp_dependencia') l
    WHERE clean.censo_label('clean.censo_escolas', 'tp_dependencia', l.code) IS DISTINCT FROM l.label;
    IF n <> 0 THEN
        RAISE EXCEPTION 'censo_label: % divergências com o dicionário em tp_dependencia', n;
    END IF;

    -- coluna sem domínio devolve zero linhas
    SELECT count(*) INTO n FROM clean.censo_labels('clean.censo_escolas', 'qt_equip_tv');
    IF n <> 0 THEN
        RAISE EXCEPTION 'censo_labels: coluna numérica sem domínio devolveu % linhas', n;
    END IF;

    -- os COMMENTs apontam para o dicionário, não repetem a lista
    IF col_description('clean.censo_escolas'::regclass,
                       (SELECT attnum FROM pg_attribute
                         WHERE attrelid = 'clean.censo_escolas'::regclass AND attname = 'tp_dependencia'))
       NOT LIKE '%censo_data_dictionary%' THEN
        RAISE EXCEPTION 'COMMENT de tp_dependencia não aponta para o dicionário';
    END IF;
END $$;

ROLLBACK;
