-- Deploy edumaps:docentes_formacao_continuada_rotulos to pg
-- requires: censo_docentes
-- requires: school_indicators
-- requires: escolas_scores_gestora
--
-- #522 (QU-01): as colunas qt_doc_bas_espec_* do Censo são a formação
-- continuada de no mínimo 80 horas ("Outros cursos" no dicionário do INEP),
-- não a especialização (pós-graduação lato sensu, qt_doc_bas_esco_sup_pos_espec).
-- Os comentários antigos diziam "especialização" e chegavam ao Assistente do
-- Censo e ao agrupamento. Só comentários: nenhum dado muda.

BEGIN;

  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_cre IS 'Docentes com formação continuada de no mínimo 80 horas em creche (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_pre_escola IS 'Docentes com formação continuada de no mínimo 80 horas em pré-escola (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_anos_iniciais IS 'Docentes com formação continuada de no mínimo 80 horas em anos iniciais (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_anos_finais IS 'Docentes com formação continuada de no mínimo 80 horas em anos finais (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ens_medio IS 'Docentes com formação continuada de no mínimo 80 horas em ensino médio (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_eja IS 'Docentes com formação continuada de no mínimo 80 horas em EJA (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ed_especial IS 'Docentes com formação continuada de no mínimo 80 horas em educação especial (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_bil_surdos IS 'Docentes com formação continuada de no mínimo 80 horas em bilinguismo para surdos (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ed_indigena IS 'Docentes com formação continuada de no mínimo 80 horas em educação indígena (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_campo IS 'Docentes com formação continuada de no mínimo 80 horas em educação do campo (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_ambiental IS 'Docentes com formação continuada de no mínimo 80 horas em educação ambiental (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_dir_humanos IS 'Docentes com formação continuada de no mínimo 80 horas em direitos humanos (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_div_sexual IS 'Docentes com formação continuada de no mínimo 80 horas em diversidade sexual (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_dir_adolesc IS 'Docentes com formação continuada de no mínimo 80 horas em direitos de adolescentes (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_afro IS 'Docentes com formação continuada de no mínimo 80 horas em educação afro-brasileira (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_gestao IS 'Docentes com formação continuada de no mínimo 80 horas em gestão (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_educ_tic IS 'Docentes com formação continuada de no mínimo 80 horas em educação e TIC (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_outros IS 'Docentes com outra formação continuada de no mínimo 80 horas (não é pós-graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_espec_nenhum IS 'Docentes sem formação continuada de no mínimo 80 horas (INEP: Outros cursos, Formação Continuada, Nenhum). Não é a pós-graduação: essa está em qt_doc_bas_esco_sup_pos_*';
  COMMENT ON COLUMN clean.school_indicators.prop_sem_especializacao IS
    'Proporção de docentes sem formação continuada de no mínimo 80 horas (qt_doc_bas_espec_nenhum / qt_doc_bas). O nome da coluna é histórico: não é a pós-graduação (especialização)';
  COMMENT ON COLUMN clean.mv_escolas_scores.score_capacitacao_docente IS
    'Formação superior, pós-graduação, vínculo efetivo, formação continuada (cursos de no mínimo 80 horas).';

COMMIT;
