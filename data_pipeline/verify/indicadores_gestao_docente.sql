-- Verify edumaps:indicadores_gestao_docente on pg

BEGIN;

  SELECT 1 FROM pg_proc WHERE proname = 'gestor_indicators';
  SELECT 1 FROM pg_proc WHERE proname = 'docente_indicators';
  SELECT 1 FROM pg_proc WHERE proname = 'school_indicators';

  -- Teste com uma escola existente (ex: Ubatuba)
  DO $$
  DECLARE
      test_school BIGINT := 11000023;
      result JSON;
  BEGIN
      result := clean.gestor_indicators(test_school);
      IF result IS NULL THEN
          RAISE EXCEPTION 'gestor_indicators retornou NULL';
      END IF;
      
      result := clean.docente_indicators(test_school);
      IF result IS NULL THEN
          RAISE EXCEPTION 'docente_indicators retornou NULL';
      END IF;
      
      result := clean.school_indicators(test_school);
      IF result IS NULL THEN
          RAISE EXCEPTION 'school_indicators retornou NULL';
      END IF;
  END $$;

ROLLBACK;
