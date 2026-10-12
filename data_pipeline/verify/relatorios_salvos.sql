-- Verify edumaps:relatorios_salvos on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Colunas checadas por pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- 1. a tabela existe
    IF to_regclass('clean.relatorios_salvos') IS NULL THEN
        RAISE EXCEPTION 'clean.relatorios_salvos ausente';
    END IF;

    -- 2. colunas
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.relatorios_salvos'::regclass
      AND attname IN ('id', 'gestor_id', 'cod_inep', 'job_id', 'tema_id', 'tema_titulo',
                      'nivel', 'codigo', 'recorte_nome', 'opcoes', 'titulo',
                      'conteudo', 'gerado_em', 'created_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 14 THEN
        RAISE EXCEPTION 'relatorios_salvos: colunas ausentes (esperadas 14, encontradas %)', n;
    END IF;

    -- 3. FK para clean.gestores com ON DELETE CASCADE
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.relatorios_salvos'::regclass
      AND contype = 'f'
      AND confrelid = 'clean.gestores'::regclass
      AND confdeltype = 'c';
    IF n <> 1 THEN
        RAISE EXCEPTION 'relatorios_salvos: FK gestor_id -> clean.gestores ON DELETE CASCADE ausente';
    END IF;

    -- 4. UNIQUE (gestor_id, job_id)
    SELECT count(*) INTO n
    FROM pg_constraint c
    WHERE c.conrelid = 'clean.relatorios_salvos'::regclass
      AND c.contype = 'u'
      AND (SELECT array_agg(a.attname::text ORDER BY a.attname)
             FROM pg_attribute a
            WHERE a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey))
          = ARRAY['gestor_id', 'job_id'];
    IF n <> 1 THEN
        RAISE EXCEPTION 'relatorios_salvos: UNIQUE (gestor_id, job_id) ausente';
    END IF;

    -- 5. CHECK do nível
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.relatorios_salvos'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%nivel%';
    IF n <> 1 THEN
        RAISE EXCEPTION 'relatorios_salvos: CHECK de nivel ausente';
    END IF;

    -- 6. índice de listagem
    IF to_regclass('clean.idx_relatorios_salvos_gestor') IS NULL THEN
        RAISE EXCEPTION 'idx_relatorios_salvos_gestor ausente';
    END IF;
END
$$;

ROLLBACK;
