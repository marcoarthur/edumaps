-- Verify edumaps:raw_populacao on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.
--
-- Nota: as asserções de linha específica ('Alta Floresta D''Oeste') e de
-- conversão de 'NA' para NULL foram substituídas por asserções estruturais e
-- de não-vazio: eram dependentes do recorte de dados e nunca falhavam.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'raw' AND table_name = 'populacao_raw';
    IF n <> 1 THEN
        RAISE EXCEPTION 'raw_populacao: raw.populacao_raw ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'populacao_municipal';
    IF n <> 1 THEN
        RAISE EXCEPTION 'raw_populacao: clean.populacao_municipal ausente';
    END IF;

    SELECT count(*) INTO n FROM clean.populacao_municipal;
    IF n = 0 THEN
        RAISE EXCEPTION 'raw_populacao: clean.populacao_municipal vazia';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.table_constraints
    WHERE table_schema = 'clean' AND table_name = 'populacao_municipal' AND constraint_type = 'PRIMARY KEY';
    IF n < 1 THEN
        RAISE EXCEPTION 'raw_populacao: PK de clean.populacao_municipal ausente';
    END IF;
END $$;

ROLLBACK;
