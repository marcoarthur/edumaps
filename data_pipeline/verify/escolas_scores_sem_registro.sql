-- Verify edumaps:escolas_scores_sem_registro on pg
--
-- Falha de verdade (DO + RAISE, #160) se a MV ainda puser 0 onde falta o
-- registro, ou se o comentário não trouxer indices-v3.

BEGIN;

  DO $$
  DECLARE
      def text := pg_get_viewdef('clean.mv_escolas_scores'::regclass);
  BEGIN
      IF def ~ 'COALESCE\(doc\.score_capacitacao_docente' OR def ~ 'COALESCE\(div\.score_diversidade_discente'
         OR def ~ 'COALESCE\(cap\.score_capacidade_atendimento' OR def ~ 'COALESCE\(ges\.score_capacidade_gestora' THEN
          RAISE EXCEPTION 'mv_escolas_scores ainda troca o índice ausente por 0 (#467)';
      END IF;
      IF EXISTS (
          SELECT 1 FROM clean.mv_escolas_scores s
           WHERE s.score_capacitacao_docente IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM clean.censo_docentes d
                              WHERE d.co_entidade = s.co_entidade AND d.nu_ano_censo = s.nu_ano_censo
                                AND d.qt_doc_bas > 0)) THEN
          RAISE EXCEPTION 'escola sem docente com score_capacitacao_docente (#467)';
      END IF;
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v3 ' THEN
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem indices-v3';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'clean' AND indexname = 'idx_mv_scores_pk') THEN
          RAISE EXCEPTION 'índice idx_mv_scores_pk ausente';
      END IF;
  END $$;

ROLLBACK;
