-- Verify edumaps:gestor_pesquisas from pg
-- requires: schemas

BEGIN;

  SELECT pg_catalog.set_config('search_path', '', false);

  SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
  FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name IN ('gestores', 'gestor_pesquisas', 'gestor_pesquisas_perguntas')
  HAVING COUNT(*) = 3;

  SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
  FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name   = 'gestor_pesquisas'
    AND column_name  IN ('id', 'cod_inep', 'gestor_id', 'titulo', 'descricao',
                         'status', 'created_at', 'updated_at')
  HAVING COUNT(*) = 8;

  SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END
  FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name   = 'gestor_pesquisas_perguntas'
    AND column_name  IN ('id', 'pesquisa_id', 'ordem', 'texto', 'tipo',
                         'obrigatoria', 'opcoes')
  HAVING COUNT(*) = 7;

ROLLBACK;