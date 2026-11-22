-- Revert edumaps:docentes_formacao_continuada_rotulos from pg
--
-- Volta os comentários de antes da #522.

BEGIN;

  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_cre IS 'Docentes com especialização em creche';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_pre_escola IS 'Docentes com especialização em pré-escola';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_anos_iniciais IS 'Docentes com especialização em anos iniciais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_anos_finais IS 'Docentes com especialização em anos finais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ens_medio IS 'Docentes com especialização em ensino médio';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_eja IS 'Docentes com especialização em EJA';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ed_especial IS 'Docentes com especialização em educação especial';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_bil_surdos IS 'Docentes com especialização em bilinguismo para surdos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ed_indigena IS 'Docentes com especialização em educação indígena';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_campo IS 'Docentes com especialização em educação do campo';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ambiental IS 'Docentes com especialização em educação ambiental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_dir_humanos IS 'Docentes com especialização em direitos humanos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_div_sexual IS 'Docentes com especialização em diversidade sexual';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_dir_adolesc IS 'Docentes com especialização em direitos de adolescentes';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_afro IS 'Docentes com especialização em educação afro-brasileira';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_gestao IS 'Docentes com especialização em gestão';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_educ_tic IS 'Docentes com especialização em educação e TIC';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_outros IS 'Docentes com outras especializações';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_nenhum IS 'Docentes sem especialização';
  COMMENT ON COLUMN clean.school_indicators.prop_sem_especializacao IS
    'Proporção de docentes sem especialização (qt_doc_bas_espec_nenhum / qt_doc_bas)';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_capacitacao_docente IS
    'Formação superior, pós-graduação, vínculo efetivo, especializações.';

COMMIT;
