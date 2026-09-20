-- Verify edumaps:gestor_reunioes_grupos_folha from pg

BEGIN;

  SELECT gestor_id IS NULL, origem
  FROM clean.contato_grupos
  LIMIT 1;

  SELECT 1/COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name   = 'contato_grupos'
    AND column_name  = 'origem'
    AND is_nullable  = 'NO';

ROLLBACK;