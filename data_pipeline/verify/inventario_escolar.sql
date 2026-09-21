-- Verify edumaps:inventario_escolar from pg

BEGIN;

  -- Todas as novas tabelas precisam existir.
  SELECT 1/COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name IN (
      'inventario_categorias',
      'inventario_fornecedores',
      'inventario_itens',
      'inventario_anexos'
    );

  -- CHECKs de tipo/origem.
  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace AND conname IN (
      'inventario_categorias_tipo_check',
      'inventario_categorias_origem_check'
    );

  -- Índices únicos e GIN.
  SELECT 1/COUNT(*) FROM pg_indexes
    WHERE schemaname = 'clean' AND indexname IN (
      'uq_inventario_categorias_inep_tipo_nome',
      'uq_inventario_fornecedores_inep_nome',
      'uq_inventario_itens_inep_censo_ref',
      'idx_inventario_itens_atributos'
    );

  -- FK de anexo -> item com cascade.
  SELECT 1/COUNT(*) FROM pg_constraint
    WHERE connamespace = 'clean'::regnamespace
      AND conrelid = 'clean.inventario_anexos'::regclass
      AND confrelid = 'clean.inventario_itens'::regclass
      AND confdeltype = 'c';

COMMIT;
