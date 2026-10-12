-- Verify edumaps:relatorios_salvos_assistente on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Coluna checada por pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- 1. a coluna existe, é text e NOT NULL
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.relatorios_salvos'::regclass
      AND attname = 'assistente'
      AND atttypid = 'text'::regtype
      AND attnotnull
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 1 THEN
        RAISE EXCEPTION 'relatorios_salvos.assistente ausente (ou não é text NOT NULL)';
    END IF;

    -- 2. DEFAULT 'relatorio'
    SELECT count(*) INTO n
    FROM pg_attrdef d
    JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
    WHERE d.adrelid = 'clean.relatorios_salvos'::regclass
      AND a.attname = 'assistente'
      AND pg_get_expr(d.adbin, d.adrelid) LIKE '%''relatorio''%';
    IF n <> 1 THEN
        RAISE EXCEPTION 'relatorios_salvos.assistente sem DEFAULT ''relatorio''';
    END IF;
END
$$;

ROLLBACK;
