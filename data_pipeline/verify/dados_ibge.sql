-- Verify edumaps:dados_ibge on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'dados_ibge';
    IF n <> 1 THEN
        RAISE EXCEPTION 'dados_ibge: clean.dados_ibge ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'dados_ibge'
      AND column_name IN ('codigo_ibge', 'ano', 'pib_total');
    IF n <> 3 THEN
        RAISE EXCEPTION 'dados_ibge: esperava colunas codigo_ibge/ano/pib_total, encontrei %', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.table_constraints
    WHERE table_schema = 'clean' AND table_name = 'dados_ibge' AND constraint_type = 'PRIMARY KEY';
    IF n < 1 THEN
        RAISE EXCEPTION 'dados_ibge: PK ausente';
    END IF;
END $$;

ROLLBACK;
