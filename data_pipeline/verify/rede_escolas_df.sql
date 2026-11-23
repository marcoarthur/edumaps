-- Verify edumaps:rede_escolas_df on pg
--
-- #545: no DF, as privadas conveniadas com o governo distrital (esfera
-- estadual) contam como conveniadas. Sem o DF no banco (fixtures do CI), o
-- verify só confere que a regra de rede_escolas_conveniadas continua.

BEGIN;

DO $$
DECLARE
    esperado bigint;
    na_mv bigint;
BEGIN
    SELECT count(DISTINCT co_entidade) INTO esperado
      FROM clean.censo_escolas
     WHERE co_municipio::text = '5300108' AND tp_situacao_funcionamento = 1
       AND tp_dependencia = 4 AND in_poder_publico_parceria = 1 AND tp_poder_publico_parceria IN (1, 2, 3);
    SELECT COALESCE(sum(escolas_conveniadas), 0) INTO na_mv
      FROM analytics.mv_rede_escolas WHERE co_municipio::text = '5300108';
    IF na_mv <> esperado THEN
        RAISE EXCEPTION 'mv_rede_escolas: DF com % escolas conveniadas, esperado % (#545)', na_mv, esperado;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_description
                    WHERE objoid = 'analytics.mv_rede_escolas'::regclass AND description LIKE '%governo distrital%') THEN
        RAISE EXCEPTION 'mv_rede_escolas sem o comentário do DF (#545)';
    END IF;
END $$;

ROLLBACK;
