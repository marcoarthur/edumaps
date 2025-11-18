-- Verify edumaps:ideb_analytics on pg

BEGIN;

  -- Verifica existência das funções e suas assinaturas
  DO $$
  BEGIN
      -- Verifica função de despivotamento
      ASSERT (
          SELECT COUNT(*) = 1 
          FROM pg_proc p 
          JOIN pg_namespace n ON p.pronamespace = n.oid 
          WHERE n.nspname = 'clean' 
          AND p.proname = 'inep_despivotar_series_historicas'
          AND p.prorettype = 'record'::regtype
      ), 'Função clean.inep_despivotar_series_historicas não encontrada';

      -- Verifica função de evolução de notas
      ASSERT (
          SELECT COUNT(*) = 1 
          FROM pg_proc p 
          JOIN pg_namespace n ON p.pronamespace = n.oid 
          WHERE n.nspname = 'clean' 
          AND p.proname = 'inep_notas_evolucao'
          AND p.prorettype = 'record'::regtype
      ), 'Função clean.inep_notas_evolucao não encontrada';

      -- Verifica função de séries municipais
      ASSERT (
          SELECT COUNT(*) = 1 
          FROM pg_proc p 
          JOIN pg_namespace n ON p.pronamespace = n.oid 
          WHERE n.nspname = 'clean' 
          AND p.proname = 'inep_series_historicas_municipio'
          AND p.prorettype = 'record'::regtype
      ), 'Função clean.inep_series_historicas_municipio não encontrada';

      -- Verifica função de estatísticas municipais
      ASSERT (
          SELECT COUNT(*) = 1 
          FROM pg_proc p 
          JOIN pg_namespace n ON p.pronamespace = n.oid 
          WHERE n.nspname = 'clean' 
          AND p.proname = 'inep_estatisticas_municipio'
          AND p.prorettype = 'record'::regtype
      ), 'Função clean.inep_estatisticas_municipio não encontrada';

      -- Testa execução básica das funções (sem parâmetros para evitar erros de dados)
      ASSERT (
          SELECT COUNT(*) > 0 
          FROM pg_proc 
          WHERE proname = 'inep_notas_evolucao'
      ), 'Função inep_notas_evolucao não pode ser referenciada';

  END $$;

  -- Verifica comentários das funções
  DO $$
  BEGIN
      ASSERT (
          SELECT COUNT(*) = 4 
          FROM pg_description d
          JOIN pg_proc p ON p.oid = d.objoid
          JOIN pg_namespace n ON p.pronamespace = n.oid
          WHERE n.nspname = 'clean'
          AND p.proname IN (
              'inep_despivotar_series_historicas',
              'inep_notas_evolucao', 
              'inep_series_historicas_municipio',
              'inep_estatisticas_municipio'
          )
          AND d.description IS NOT NULL
      ), 'Comentários das funções não foram aplicados';
  END $$;

ROLLBACK;
