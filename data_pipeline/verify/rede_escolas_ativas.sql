-- Verify edumaps:rede_escolas_ativas on pg
--
-- Falha de verdade (DO + RAISE, #160) se a MV contar escola fora de
-- funcionamento: o total de escolas da MV tem de ser igual ao número de
-- escolas em funcionamento com município e dependência.

BEGIN;

DO $$
DECLARE
    n_mv bigint;
    n_ativas bigint;
BEGIN
    SELECT COALESCE(sum(total_escolas), 0) INTO n_mv FROM analytics.mv_rede_escolas;
    SELECT count(DISTINCT co_entidade) INTO n_ativas
      FROM clean.censo_escolas
     WHERE tp_situacao_funcionamento = 1 AND co_municipio IS NOT NULL AND tp_dependencia IS NOT NULL;
    IF n_mv <> n_ativas THEN
        RAISE EXCEPTION 'mv_rede_escolas soma % escolas, mas há % em funcionamento (#479)', n_mv, n_ativas;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'analytics.mv_rede_escolas'::regclass AND attname = 'alunos_por_escola') THEN
        RAISE EXCEPTION 'mv_rede_escolas sem alunos_por_escola';
    END IF;
END $$;

ROLLBACK;
