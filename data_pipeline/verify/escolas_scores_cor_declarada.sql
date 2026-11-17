-- Verify edumaps:escolas_scores_cor_declarada on pg
--
-- Falha de verdade (DO + RAISE, #160) se a diversidade não bater com a
-- fórmula da indices-v4 (parte racial sobre os declarados, peso
-- redistribuído abaixo de metade declarada) ou se o COMMENT não trouxer a
-- versão.

BEGIN;

  DO $$
  DECLARE
      n integer;
  BEGIN
      SELECT count(*) INTO n
        FROM clean.mv_escolas_scores s
        JOIN (
          SELECT m.co_entidade, m.nu_ano_censo, m.qt_mat_bas,
                 ( COALESCE(qt_mat_bas_branca,0) + COALESCE(qt_mat_bas_preta,0) + COALESCE(qt_mat_bas_parda,0)
                 + COALESCE(qt_mat_bas_amarela,0) + COALESCE(qt_mat_bas_indigena,0) )::numeric AS decl,
                 COALESCE(qt_mat_bas_branca,0) br, COALESCE(qt_mat_bas_preta,0) pr, COALESCE(qt_mat_bas_parda,0) pa,
                 COALESCE(qt_mat_bas_amarela,0) am, COALESCE(qt_mat_bas_indigena,0) ind,
                 2 * LEAST(1, LEAST(COALESCE(qt_mat_bas_fem,0), COALESCE(qt_mat_bas_masc,0))::numeric / qt_mat_bas) AS g,
                 LEAST(1, COALESCE(qt_mat_esp_cc,0)::numeric / qt_mat_bas) AS i,
                 LEAST(1, COALESCE(qt_mat_eja,0)::numeric / qt_mat_bas) AS e
            FROM clean.censo_matriculas m WHERE m.qt_mat_bas > 0
        ) x ON x.co_entidade = s.co_entidade AND x.nu_ano_censo = s.nu_ano_censo
       WHERE abs(s.score_diversidade_discente - round(
               CASE WHEN x.decl > 0 AND x.decl >= 0.5 * x.qt_mat_bas
                    THEN 3.5 * (1 - (power(x.br/x.decl,2) + power(x.pr/x.decl,2) + power(x.pa/x.decl,2)
                                   + power(x.am/x.decl,2) + power(x.ind/x.decl,2)))
                         + 2.5 * x.g + 2 * x.i + 2 * x.e
                    ELSE (2.5 * x.g + 2 * x.i + 2 * x.e) / 0.65 END, 2)) > 0.005;
      IF n > 0 THEN
          RAISE EXCEPTION 'score_diversidade_discente fora da fórmula indices-v4 em % escolas (#471)', n;
      END IF;
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v([4-9]|[1-9][0-9]+) ' THEN   -- v4 ou posterior
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem indices-v4 ou posterior';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
  END $$;

ROLLBACK;
