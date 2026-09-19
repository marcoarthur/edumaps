-- Verify edumaps:gestor_respostas from pg

BEGIN;

  -- Colunas adicionadas em tabelas existentes.
  SELECT 1/COUNT(*) FROM information_schema.columns
    WHERE table_schema = 'clean'
      AND table_name = 'gestor_pesquisas' AND column_name = 'token';

  SELECT 1/COUNT(*) FROM information_schema.columns
    WHERE table_schema = 'clean'
      AND table_name = 'gestores' AND column_name = 'senha_hash';

  -- Novas tabelas.
  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN (
      'sessoes',
      'gestor_pesquisas_respostas',
      'gestor_pesquisas_respostas_itens'
    );

COMMIT;