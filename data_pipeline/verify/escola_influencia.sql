-- Verify edumaps:escola_influencia on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Colunas checadas por pg_attribute
-- (information_schema não lista colunas de matviews). Não checa volume de
-- dados: em base recém-deployada o censo pode estar vazio (gate de CI).

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- 1. tabela existe
    IF to_regclass('clean.escola_influencia') IS NULL THEN
        RAISE EXCEPTION 'clean.escola_influencia ausente';
    END IF;

    -- 2. colunas
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.escola_influencia'::regclass
      AND attname IN ('co_entidade', 'nu_ano_censo', 'tier', 'raio_m',
                      'geom', 'versao', 'computado_em')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 7 THEN
        RAISE EXCEPTION 'escola_influencia: colunas (esperadas 7, encontradas %)', n;
    END IF;

    -- 3. primary key
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'pk_escola_influencia' AND contype = 'p'
    ) THEN
        RAISE EXCEPTION 'PK pk_escola_influencia ausente';
    END IF;

    -- 4. índice espacial
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'clean' AND indexname = 'ix_escola_influencia_geom'
    ) THEN
        RAISE EXCEPTION 'índice ix_escola_influencia_geom ausente';
    END IF;

    -- 5. função de refresh
    IF to_regprocedure('clean.refresh_escola_influencia(integer[],bigint[])') IS NULL THEN
        RAISE EXCEPTION 'função clean.refresh_escola_influencia(integer[],bigint[]) ausente';
    END IF;
END $$;

ROLLBACK;
