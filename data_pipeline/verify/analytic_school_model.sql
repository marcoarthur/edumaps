-- Verify edumaps:analytic_school_model on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- A função tem de existir com a assinatura exata usada pelo motor.
    -- pg_get_function_identity_arguments inclui os NOMES dos parâmetros.
    SELECT count(*) INTO n
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
    WHERE ns.nspname = 'analytics'
      AND p.proname = 'prepare_school_data'
      AND pg_get_function_identity_arguments(p.oid) =
          'p_censo_year integer, p_ideb_year integer, p_inse_year integer, p_etapa text';
    IF n < 1 THEN
        RAISE EXCEPTION 'analytic_school_model: analytics.prepare_school_data(p_censo_year integer, p_ideb_year integer, p_inse_year integer, p_etapa text) ausente';
    END IF;
END $$;

ROLLBACK;
