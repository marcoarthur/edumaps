-- Verify edumaps:escolas_scores_vinculo on pg
--
-- Falha de verdade (DO + RAISE, #160) se a capacitação docente não bater com
-- a fórmula da indices-v7 (concursados vazios nas privadas, peso
-- redistribuído), se o COMMENT não trouxer indices-v7 ou posterior, ou se os
-- comentários da #524 faltarem.

BEGIN;

  DO $$
  DECLARE
      n integer;
  BEGIN
      SELECT count(*) INTO n
        FROM (
          SELECT s.score_capacitacao_docente AS atual,
                 LEAST(1, COALESCE(d.qt_doc_bas_esco_sup_grad,0)::numeric / d.qt_doc_bas) * 10 AS p1,
                 LEAST(1, (COALESCE(d.qt_doc_bas_esco_sup_pos_espec,0) + COALESCE(d.qt_doc_bas_esco_sup_pos_mestra,0)
                           + COALESCE(d.qt_doc_bas_esco_sup_pos_douto,0))::numeric / d.qt_doc_bas) * 10 AS p2,
                 CASE WHEN e.tp_dependencia IS DISTINCT FROM 4
                      THEN LEAST(1, COALESCE(d.qt_doc_bas_vinculo_concur,0)::numeric / d.qt_doc_bas) * 10 END AS p3,
                 LEAST(1, (COALESCE(d.qt_doc_bas_espec_cre,0) + COALESCE(d.qt_doc_bas_espec_pre_escola,0)
                           + COALESCE(d.qt_doc_bas_espec_anos_iniciais,0) + COALESCE(d.qt_doc_bas_espec_anos_finais,0)
                           + COALESCE(d.qt_doc_bas_espec_ens_medio,0) + COALESCE(d.qt_doc_bas_espec_eja,0)
                           + COALESCE(d.qt_doc_bas_espec_ed_especial,0) + COALESCE(d.qt_doc_bas_espec_bil_surdos,0)
                           + COALESCE(d.qt_doc_bas_espec_ed_indigena,0) + COALESCE(d.qt_doc_bas_espec_campo,0)
                           + COALESCE(d.qt_doc_bas_espec_ambiental,0) + COALESCE(d.qt_doc_bas_espec_dir_humanos,0)
                           + COALESCE(d.qt_doc_bas_espec_div_sexual,0) + COALESCE(d.qt_doc_bas_espec_dir_adolesc,0)
                           + COALESCE(d.qt_doc_bas_espec_afro,0) + COALESCE(d.qt_doc_bas_espec_gestao,0)
                           + COALESCE(d.qt_doc_bas_espec_educ_tic,0) + COALESCE(d.qt_doc_bas_espec_outros,0))::numeric
                           / d.qt_doc_bas) * 10 AS p4
            FROM clean.mv_escolas_scores s
            JOIN clean.censo_docentes d ON d.co_entidade = s.co_entidade AND d.nu_ano_censo = s.nu_ano_censo
            LEFT JOIN clean.censo_escolas e ON e.co_entidade = s.co_entidade AND e.nu_ano_censo = s.nu_ano_censo
           WHERE d.qt_doc_bas > 0
        ) x
       WHERE abs(x.atual - round(
               (0.3 * x.p1 + 0.3 * x.p2 + 0.2 * COALESCE(x.p3,0) + 0.2 * x.p4)
               / (CASE WHEN x.p3 IS NULL THEN 0.8 ELSE 1 END), 2)) > 0.005
          OR x.atual IS NULL;
      IF n > 0 THEN
          RAISE EXCEPTION 'score_capacitacao_docente fora da fórmula indices-v7 em % escolas (#524)', n;
      END IF;
      IF coalesce(obj_description('clean.mv_escolas_scores'::regclass, 'pg_class'), '') !~ 'VERSÃO indices-v([7-9]|[1-9][0-9]+) ' THEN
          RAISE EXCEPTION 'comentário de clean.mv_escolas_scores sem indices-v7 ou posterior';
      END IF;
      IF coalesce(col_description('clean.mv_escolas_scores'::regclass,
           (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.mv_escolas_scores'::regclass
               AND attname = 'score_capacitacao_docente')), '') !~ 'NULL sem docente \(#467\)' THEN
          RAISE EXCEPTION 'comentário de score_capacitacao_docente sem "NULL sem docente (#467)"';
      END IF;
      IF coalesce(col_description('clean.school_indicators'::regclass,
           (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.school_indicators'::regclass
               AND attname = 'prop_efetivos')), '') !~ 'vazia nas privadas' THEN
          RAISE EXCEPTION 'comentário de school_indicators.prop_efetivos sem as privadas (#524)';
      END IF;
      IF NOT has_table_privilege('edumaps_leitor', 'clean.mv_escolas_scores', 'SELECT') THEN
          RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.mv_escolas_scores';
      END IF;
  END $$;

ROLLBACK;
