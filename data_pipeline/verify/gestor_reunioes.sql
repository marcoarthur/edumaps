-- Verify edumaps:gestor_reunioes from pg

BEGIN;

  -- Todas as novas tabelas precisam existir.
  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN (
      'contato_grupos',
      'contatos',
      'reunioes',
      'reunioes_participantes',
      'reuniao_anexos'
    );

  -- CHECKs de status/método e FKs essenciais.
  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace AND conname IN (
      'reunioes_aviso_metodo_check',
      'reunioes_status_check',
      'reuniao_anexos_tipo_check'
    );

  -- Índice parcial de e-mail único por escola (contatos).
  SELECT 1/COUNT(*) FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname = 'uq_contatos_inep_email';

COMMIT;