-- Verify edumaps:escolas_scores_turnos on pg
--
-- Falha de verdade (DO + RAISE, #160) se a capacidade de atendimento não
-- bater com a fórmula da indices-v5 (alunos por sala e por turno) ou se o
-- COMMENT não trouxer indices-v5 ou posterior.

BEGIN;

  DO $$
  DECLARE
      n integer;
  BEGIN
      SELECT count(*) INTO n
        FROM clean.mv_escolas_scores s
        JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
        JOIN clean.censo_matriculas m ON m.co_entidade = s.co_entidade AND m.nu_ano_censo = s.nu_ano_censo
       WHERE m.qt_mat_bas > 0
         AND abs(s.score_capacidade_atendimento - round(
               0.4 * CASE WHEN e.qt_salas_utilizadas > 0
                          THEN GREATEST(0, 10 * (1 - (m.qt_mat_bas::numeric / (e.qt_salas_utilizadas *
                                 GREATEST(1, (COALESCE(m.qt_mat_bas_dm,0) > 0)::int + (COALESCE(m.qt_mat_bas_dv,0) > 0)::int
                                             + (COALESCE(m.qt_mat_bas_n,0) > 0)::int))) / 50))
                          ELSE 0 END
             + 0.2 * ( (COALESCE(e.in_comum_creche,0) + COALESCE(e.in_comum_pre,0) + COALESCE(e.in_comum_fund_ai,0)
                      + COALESCE(e.in_comum_fund_af,0) + COALESCE(e.in_comum_medio_medio,0) + COALESCE(e.in_eja,0)
                      + COALESCE(e.in_profissionalizante,0)) / 7.0 * 10 )
             + 0.2 * (COALESCE(m.qt_mat_bas_int,0)::numeric / m.qt_mat_bas) * 10
             + 0.2 * CASE WHEN e.in_alimentacao = 1 THEN 10 ELSE 0 END, 2)) > 0.005;
      IF n > 0 THEN
          RAISE EXCEPTION 'score_capacidade_atendimento fora da fórmula indices-v5 em % escolas (#473)', n;
      END IF;
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v([5-9]|[1-9][0-9]+) ' THEN
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem indices-v5 ou posterior';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
  END $$;

ROLLBACK;
