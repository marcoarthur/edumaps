-- Verify edumaps:analytical_views_for_modeling on pg

BEGIN;

  -- Verifica existência da view
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 1
          FROM pg_views
          WHERE schemaname = 'analytics'
            AND viewname = 'view_escolas_ml'
      ), 'View analytics.view_escolas_ml não encontrada';
  END $$;

  -- Verifica colunas essenciais
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) >= 10
          FROM information_schema.columns
          WHERE table_schema = 'analytics'
            AND table_name = 'view_escolas_ml'
      ), 'View não possui colunas suficientes';
  END $$;

  -- Verifica presença do target
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 1
          FROM information_schema.columns
          WHERE table_schema = 'analytics'
            AND table_name = 'view_escolas_ml'
            AND column_name = 'vl_nota_media_2023'
      ), 'Coluna target vl_nota_media_2023 não encontrada';
  END $$;

  -- Verifica que a view retorna dados
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) > 0
          FROM analytics.view_escolas_ml
      ), 'View não retorna dados';
  END $$;

  -- Verifica ausência de leakage básico (sanidade)
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 0
          FROM information_schema.columns
          WHERE table_schema = 'analytics'
            AND table_name = 'view_escolas_ml'
            AND column_name LIKE '%2023'
            AND column_name <> 'vl_nota_media_2023'
      ), 'Possível leakage: colunas de 2023 indevidas encontradas';
  END $$;

  -- Verifica comentário
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 1
          FROM pg_description d
          JOIN pg_class c ON c.oid = d.objoid
          JOIN pg_namespace n ON c.relnamespace = n.oid
          WHERE n.nspname = 'analytics'
            AND c.relname = 'view_escolas_ml'
            AND d.description IS NOT NULL
      ), 'Comentário da view não encontrado';
  END $$;

  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 1
          FROM pg_views
          WHERE schemaname = 'analytics'
            AND viewname = 'view_escolas_ml_spatial'
      ), 'View spatial não encontrada';
  END $$;

  -- 4. Smoke test ULTRA LEVE (sem full scan)
  DO $$
  DECLARE
      v_dummy INTEGER;
  BEGIN
      SELECT 1
      INTO v_dummy
      FROM analytics.view_escolas_ml_spatial
      LIMIT 1;

      ASSERT v_dummy = 1, 'View não retornou dados no teste mínimo';
  END $$;

  -- 5. Anti-leakage (somente metadado, sem scan)
  DO $$
  BEGIN
      ASSERT NOT EXISTS (
          SELECT 1
          FROM pg_attribute
          WHERE attrelid = 'analytics.view_escolas_ml_spatial'::regclass
            AND attname LIKE '%2023'
            AND attname <> 'vl_nota_media_2023'
            AND NOT attisdropped
      ), 'Possível leakage: colunas 2023 indevidas';
  END $$;

ROLLBACK;
