-- Verify edumaps:analytic_school_model on pg

BEGIN;

-- XXX Add verifications here.

  -- Verifica se a função com a assinatura específica ainda existe
  SELECT 
    CASE 
      WHEN EXISTS (
        SELECT 1 
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'analytics'
          AND p.proname = 'prepare_school_data'
          AND pg_get_function_identity_arguments(p.oid) = 
              'integer, integer, integer, text'  -- ordem e tipos dos parâmetros
      ) THEN 'FUNCTION EXISTS: true'
      ELSE 'FUNCTION EXISTS: false'
    END AS verification_result;

ROLLBACK;
