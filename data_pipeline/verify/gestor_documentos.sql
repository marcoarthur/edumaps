-- Verify edumaps:gestor_documentos from pg
-- requires: gestor_respostas
--
-- Falha (RAISE) se as tabelas do módulo de documentos escolares não existirem
-- ou se a proteção de unicidade por escola/pai não estiver ativa.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'clean' AND tablename = 'pastas_escolares') THEN
    RAISE EXCEPTION 'clean.pastas_escolares nao existe';
  END IF;

  IF NOT EXISTS (
    SELECT FROM pg_indexes WHERE schemaname = 'clean' AND tablename = 'pastas_escolares'
      AND indexname = 'uq_pastas_escolares_inep_pai_nome'
  ) THEN
    RAISE EXCEPTION 'indice uq_pastas_escolares_inep_pai_nome ausente';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'clean' AND tablename = 'escola_documentos') THEN
    RAISE EXCEPTION 'clean.escola_documentos nao existe';
  END IF;

  IF NOT EXISTS (
    SELECT FROM pg_indexes WHERE schemaname = 'clean' AND tablename = 'escola_documentos'
      AND indexname = 'uq_escola_documentos_inep_pasta_nome'
  ) THEN
    RAISE EXCEPTION 'indice uq_escola_documentos_inep_pasta_nome ausente';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'clean' AND tablename = 'escola_documentos_versoes') THEN
    RAISE EXCEPTION 'clean.escola_documentos_versoes nao existe';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'clean' AND tablename = 'escola_documentos_auditoria') THEN
    RAISE EXCEPTION 'clean.escola_documentos_auditoria nao existe';
  END IF;
END $$;