-- Revert edumaps:censo_turno_comments from pg
--
-- Restaura os rotulos anteriores (incorretos) para permitir rollback.

BEGIN;

  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_d IS 'Deficiência – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dm IS 'Deficiência – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dv IS 'Deficiência – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_n IS 'Deficiência – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_d IS 'EJA – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dm IS 'EJA – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dv IS 'EJA – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_d IS 'EJA fundamental – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dm IS 'EJA fundamental – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dv IS 'EJA fundamental – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_n IS 'EJA fundamental – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_d IS 'EJA médio – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dm IS 'EJA médio – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dv IS 'EJA médio – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_n IS 'EJA médio – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_n IS 'EJA – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_d IS 'Classe comum – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dm IS 'Classe comum – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dv IS 'Classe comum – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_n IS 'Classe comum – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_d IS 'Classe exclusiva – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dm IS 'Classe exclusiva – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dv IS 'Classe exclusiva – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_n IS 'Classe exclusiva – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_d IS 'Educação especial – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dm IS 'Educação especial – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dv IS 'Educação especial – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_n IS 'Educação especial – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_d IS 'Fundamental anos finais – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dm IS 'Fundamental anos finais – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dv IS 'Fundamental anos finais – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_n IS 'Fundamental anos finais – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_d IS 'Fundamental anos iniciais – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dm IS 'Fundamental anos iniciais – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dv IS 'Fundamental anos iniciais – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_n IS 'Fundamental anos iniciais – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_d IS 'Fundamental – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dm IS 'Fundamental – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dv IS 'Fundamental – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_n IS 'Fundamental – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_d IS 'Creche – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dm IS 'Creche – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dv IS 'Creche – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_n IS 'Creche – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_d IS 'Pré‑escola – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dm IS 'Pré‑escola – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dv IS 'Pré‑escola – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_n IS 'Pré‑escola – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_d IS 'Ensino médio – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dm IS 'Ensino médio – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dv IS 'Ensino médio – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_n IS 'Ensino médio – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_d IS 'Profissional – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dm IS 'Profissional – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dv IS 'Profissional – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_n IS 'Profissional – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_d IS 'Profissional técnica – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dm IS 'Profissional técnica – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dv IS 'Profissional técnica – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_n IS 'Profissional técnica – Não se aplica';

COMMIT;
