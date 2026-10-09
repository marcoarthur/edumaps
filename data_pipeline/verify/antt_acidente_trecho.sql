-- Verify edumaps:antt_acidente_trecho on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- 1) Tabela existe
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'antt_acidente_trecho';
    IF n <> 1 THEN
        RAISE EXCEPTION 'antt_acidente_trecho: clean.antt_acidente_trecho ausente';
    END IF;

    -- 2) Colunas obrigatórias existem (8)
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'antt_acidente_trecho'
      AND column_name IN ('id_acidente', 'concessionaria', 'data_acidente', 'km', 'trecho',
                          'mortos', 'feridos_graves', 'feridos_leves');
    IF n <> 8 THEN
        RAISE EXCEPTION 'antt_acidente_trecho: esperava 8 colunas obrigatórias, encontrei %', n;
    END IF;

    -- 3) Destas, as 4 que devem ser NOT NULL
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'antt_acidente_trecho'
      AND column_name IN ('id_acidente', 'concessionaria', 'data_acidente', 'trecho')
      AND is_nullable = 'NO';
    IF n <> 4 THEN
        RAISE EXCEPTION 'antt_acidente_trecho: esperava 4 colunas NOT NULL (id_acidente/concessionaria/data_acidente/trecho), encontrei %', n;
    END IF;

    -- 3) PK
    SELECT count(*) INTO n
    FROM information_schema.table_constraints
    WHERE table_schema = 'clean' AND table_name = 'antt_acidente_trecho'
      AND constraint_type = 'PRIMARY KEY' AND constraint_name = 'antt_acidente_trecho_pkey';
    IF n <> 1 THEN
        RAISE EXCEPTION 'antt_acidente_trecho: PK antt_acidente_trecho_pkey ausente';
    END IF;

    -- 4) Unique na chave bruta
    SELECT count(*) INTO n
    FROM information_schema.table_constraints
    WHERE table_schema = 'clean' AND table_name = 'antt_acidente_trecho'
      AND constraint_type = 'UNIQUE' AND constraint_name = 'uq_antt_acidente';
    IF n <> 1 THEN
        RAISE EXCEPTION 'antt_acidente_trecho: UNIQUE uq_antt_acidente ausente';
    END IF;
END $$;

ROLLBACK;
