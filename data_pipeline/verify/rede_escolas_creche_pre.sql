-- Verify edumaps:rede_escolas_creche_pre on pg
--
-- Falha de verdade (DO + RAISE, #160): as colunas novas existem (por
-- pg_attribute: information_schema não lista colunas de MV) e creche +
-- pré-escola somam a educação infantil.

BEGIN;

DO $$
DECLARE
    n_diverge bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'analytics.mv_rede_escolas'::regclass AND attname = 'matriculas_creche')
       OR NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'analytics.mv_rede_escolas'::regclass AND attname = 'matriculas_pre') THEN
        RAISE EXCEPTION 'mv_rede_escolas sem matriculas_creche ou matriculas_pre (#516)';
    END IF;
    SELECT count(*) INTO n_diverge FROM analytics.mv_rede_escolas
     WHERE matriculas_creche + matriculas_pre <> matriculas_infantil;
    IF n_diverge > 0 THEN
        RAISE EXCEPTION 'mv_rede_escolas: creche + pré-escola diferente da infantil em % linhas', n_diverge;
    END IF;
END $$;

ROLLBACK;
