-- Verify edumaps:escolas_scores_gestora on pg
--
-- Falha de verdade (DO + RAISE, #160) se a capacidade gestora não bater com
-- a fórmula da indices-v6 (partes vazias sem matrícula e nas privadas, peso
-- redistribuído) ou se o COMMENT não trouxer indices-v6 ou posterior.

BEGIN;

  DO $$
  DECLARE
      n integer;
  BEGIN
      SELECT count(*) INTO n
        FROM (
          SELECT s.score_capacidade_gestora AS atual,
                 ( LEAST(1, COALESCE(g.qt_gest_bas_esco_sup_grad,0)::numeric / g.qt_gest_bas) * 10
                 + LEAST(1, (COALESCE(g.qt_gest_bas_esco_sup_pos_espec,0) + COALESCE(g.qt_gest_bas_esco_sup_pos_mestra,0)
                             + COALESCE(g.qt_gest_bas_esco_sup_pos_douto,0))::numeric / g.qt_gest_bas) * 10 ) / 2.0 AS p1,
                 LEAST(1, COALESCE(g.qt_gest_bas_espec_gestao,0)::numeric / g.qt_gest_bas) * 10 AS p2,
                 CASE WHEN COALESCE(m.qt_mat_bas,0) > 0 THEN 10 * LEAST(1, 200.0 * g.qt_gest_bas / m.qt_mat_bas) END AS p3,
                 LEAST(1, (COALESCE(e.in_orgao_ass_pais,0) + COALESCE(e.in_orgao_ass_pais_mestres,0) + COALESCE(e.in_orgao_conselho_escolar,0)
                           + COALESCE(e.in_orgao_gremio_estudantil,0) + COALESCE(e.in_orgao_outros,0)) / 5.0) * 10 AS p4,
                 CASE WHEN e.tp_dependencia IS DISTINCT FROM 4
                      THEN LEAST(1, (COALESCE(g.qt_gest_bas_acesso_cargo_conca,0) + COALESCE(g.qt_gest_bas_acesso_cargo_eleic,0)
                                     + COALESCE(g.qt_gest_bas_acesso_cargo_p_sel,0))::numeric / g.qt_gest_bas) * 10 END AS p5
            FROM clean.mv_escolas_scores s
            JOIN clean.censo_gestor g ON g.co_entidade = s.co_entidade AND g.nu_ano_censo = s.nu_ano_censo
            LEFT JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
                                           AND e.tp_situacao_funcionamento = 1
            LEFT JOIN clean.censo_matriculas m ON m.co_entidade = s.co_entidade AND m.nu_ano_censo = s.nu_ano_censo
           WHERE g.qt_gest_bas > 0
        ) x
       WHERE abs(x.atual - round(
               (0.3 * x.p1 + 0.2 * x.p2 + 0.2 * COALESCE(x.p3,0) + 0.2 * x.p4 + 0.1 * COALESCE(x.p5,0))
               / (0.7 + CASE WHEN x.p3 IS NULL THEN 0 ELSE 0.2 END + CASE WHEN x.p5 IS NULL THEN 0 ELSE 0.1 END), 2)) > 0.005
          OR x.atual IS NULL;
      IF n > 0 THEN
          RAISE EXCEPTION 'score_capacidade_gestora fora da fórmula indices-v6 em % escolas (#475)', n;
      END IF;
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v([6-9]|[1-9][0-9]+) ' THEN
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem indices-v6 ou posterior';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
  END $$;

ROLLBACK;
