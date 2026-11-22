-- Verify edumaps:rede_escolas_conveniadas on pg
--
-- Falha de verdade (DO + RAISE, #160): as três colunas existem (por
-- pg_attribute: information_schema não lista colunas de MV), as redes
-- públicas não têm conveniadas e as conveniadas não passam do total da rede
-- privada.

BEGIN;

DO $$
DECLARE
    col text;
    n bigint;
BEGIN
    FOREACH col IN ARRAY ARRAY['escolas_conveniadas', 'matriculas_creche_conveniada', 'matriculas_pre_conveniada'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'analytics.mv_rede_escolas'::regclass
                        AND attname = col AND NOT attisdropped) THEN
            RAISE EXCEPTION 'mv_rede_escolas sem a coluna % (#518)', col;
        END IF;
    END LOOP;
    SELECT count(*) INTO n FROM analytics.mv_rede_escolas
     WHERE codigo_rede <> 4
       AND (escolas_conveniadas + matriculas_creche_conveniada + matriculas_pre_conveniada) <> 0;
    IF n > 0 THEN
        RAISE EXCEPTION 'mv_rede_escolas: % linhas de rede pública com conveniadas', n;
    END IF;
    SELECT count(*) INTO n FROM analytics.mv_rede_escolas
     WHERE escolas_conveniadas > total_escolas
        OR matriculas_creche_conveniada > matriculas_creche
        OR matriculas_pre_conveniada > matriculas_pre;
    IF n > 0 THEN
        RAISE EXCEPTION 'mv_rede_escolas: conveniadas acima do total da rede em % linhas', n;
    END IF;
END $$;

ROLLBACK;
