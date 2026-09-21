-- Deploy edumaps:censo_turno_comments to pg
-- requires: matriculas_censo_2025
--
-- Corrige os comentarios das colunas de TURNO do Censo de matriculas: os
-- sufixos _d/_dm/_dv/_n sao Diurno/Matutino/Vespertino/Noturno (validado:
-- dm+dv=d e d+n=total em 100% das linhas; d ~ 93% das matriculas), mas o
-- loader as rotulou como "Deficiencia". Educacao especial/deficiencia e
-- qt_mat_esp* (comentarios ja corretos).

BEGIN;

  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_d IS 'Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dm IS 'Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dv IS 'Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_n IS 'Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_d IS 'EJA – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dm IS 'EJA – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dv IS 'EJA – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_d IS 'EJA fundamental – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dm IS 'EJA fundamental – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dv IS 'EJA fundamental – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_n IS 'EJA fundamental – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_d IS 'EJA médio – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dm IS 'EJA médio – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dv IS 'EJA médio – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_n IS 'EJA médio – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_n IS 'EJA – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_d IS 'Classe comum – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dm IS 'Classe comum – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dv IS 'Classe comum – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_n IS 'Classe comum – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_d IS 'Classe exclusiva – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dm IS 'Classe exclusiva – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dv IS 'Classe exclusiva – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_n IS 'Classe exclusiva – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_d IS 'Educação especial – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dm IS 'Educação especial – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dv IS 'Educação especial – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_n IS 'Educação especial – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_d IS 'Fundamental anos finais – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dm IS 'Fundamental anos finais – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dv IS 'Fundamental anos finais – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_n IS 'Fundamental anos finais – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_d IS 'Fundamental anos iniciais – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dm IS 'Fundamental anos iniciais – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dv IS 'Fundamental anos iniciais – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_n IS 'Fundamental anos iniciais – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_d IS 'Fundamental – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dm IS 'Fundamental – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dv IS 'Fundamental – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_n IS 'Fundamental – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_d IS 'Creche – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dm IS 'Creche – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dv IS 'Creche – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_n IS 'Creche – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_d IS 'Pré‑escola – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dm IS 'Pré‑escola – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dv IS 'Pré‑escola – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_n IS 'Pré‑escola – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_d IS 'Ensino médio – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dm IS 'Ensino médio – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dv IS 'Ensino médio – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_n IS 'Ensino médio – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_d IS 'Profissional – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dm IS 'Profissional – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dv IS 'Profissional – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_n IS 'Profissional – Noturno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_d IS 'Profissional técnica – Diurno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dm IS 'Profissional técnica – Matutino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dv IS 'Profissional técnica – Vespertino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_n IS 'Profissional técnica – Noturno';

COMMIT;
