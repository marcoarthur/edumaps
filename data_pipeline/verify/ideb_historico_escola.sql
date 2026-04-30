-- Verify edumaps:ideb_historico_escola on pg

BEGIN;

  -- Verifica se a função existe
  SELECT 1 FROM pg_proc 
  WHERE proname = 'ideb_historico_escola' 
    AND pronamespace = 'clean'::regnamespace;

  -- Testa com uma escola que sabemos que existe no dataset (ex: 11024666 de RO)
  DO $$
  BEGIN
      PERFORM clean.ideb_historico_escola(11024666);
  EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'Função ideb_historico_escola falhou no teste: %', SQLERRM;
  END $$;

ROLLBACK;
