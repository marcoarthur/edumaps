-- Verify edumaps:escolas_scores_diversidade_esp on pg
--
-- Falha de verdade (DO + RAISE, #160) se a definição ainda somar os turnos
-- ou não usar a educação especial em classe comum.

BEGIN;

  DO $$
  DECLARE
      def text := pg_get_viewdef('clean.mv_escolas_scores'::regclass);
  BEGIN
      IF def ~ 'qt_mat_bas_dm' OR def ~ 'qt_mat_bas_dv' THEN
          RAISE EXCEPTION 'mv_escolas_scores ainda soma os turnos (qt_mat_bas_dm/dv) na diversidade';
      END IF;
      IF def !~ 'qt_mat_esp_cc' THEN
          RAISE EXCEPTION 'mv_escolas_scores não usa qt_mat_esp_cc na diversidade';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'clean' AND indexname = 'idx_mv_scores_pk') THEN
          RAISE EXCEPTION 'índice idx_mv_scores_pk ausente';
      END IF;
  END $$;

ROLLBACK;
