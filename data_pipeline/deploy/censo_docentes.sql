-- Deploy edumaps:censo_docentes to pg
-- requires: censo_escolar_2025

BEGIN;

  CREATE TABLE clean.censo_docentes (
      nu_ano_censo INTEGER NOT NULL,
      co_entidade BIGINT NOT NULL,
      qt_doc_bas INTEGER,
      qt_doc_inf INTEGER,
      qt_doc_inf_cre INTEGER,
      qt_doc_inf_pre INTEGER,
      qt_doc_fund INTEGER,
      qt_doc_fund_ai INTEGER,
      qt_doc_fund_ai_1 INTEGER,
      qt_doc_fund_ai_2 INTEGER,
      qt_doc_fund_ai_3 INTEGER,
      qt_doc_fund_ai_4 INTEGER,
      qt_doc_fund_ai_5 INTEGER,
      qt_doc_fund_ai_multietapa INTEGER,
      qt_doc_fund_af INTEGER,
      qt_doc_fund_af_6 INTEGER,
      qt_doc_fund_af_7 INTEGER,
      qt_doc_fund_af_8 INTEGER,
      qt_doc_fund_af_9 INTEGER,
      qt_doc_fund_af_multi INTEGER,
      qt_doc_fund_af_corrfluxo INTEGER,
      qt_doc_med INTEGER,
      qt_doc_med_prop INTEGER,
      qt_doc_med_prop_1 INTEGER,
      qt_doc_med_prop_2 INTEGER,
      qt_doc_med_prop_3 INTEGER,
      qt_doc_med_prop_4 INTEGER,
      qt_doc_med_prop_ns INTEGER,
      qt_doc_med_iftp_ct INTEGER,
      qt_doc_med_iftp_ct_1 INTEGER,
      qt_doc_med_iftp_ct_2 INTEGER,
      qt_doc_med_iftp_ct_3 INTEGER,
      qt_doc_med_iftp_ct_4 INTEGER,
      qt_doc_med_iftp_ct_ns INTEGER,
      qt_doc_med_iftp_qp INTEGER,
      qt_doc_med_iftp_qp_1 INTEGER,
      qt_doc_med_iftp_qp_2 INTEGER,
      qt_doc_med_iftp_qp_3 INTEGER,
      qt_doc_med_iftp_qp_4 INTEGER,
      qt_doc_med_iftp_qp_ns INTEGER,
      qt_doc_med_nm INTEGER,
      qt_doc_med_nm_1 INTEGER,
      qt_doc_med_nm_2 INTEGER,
      qt_doc_med_nm_3 INTEGER,
      qt_doc_med_nm_4 INTEGER,
      qt_doc_prof INTEGER,
      qt_doc_prof_tec INTEGER,
      qt_doc_prof_tec_con INTEGER,
      qt_doc_prof_tec_subs INTEGER,
      qt_doc_prof_tec_misto INTEGER,
      qt_doc_prof_tec_iftp_ct INTEGER,
      qt_doc_prof_nao_tec INTEGER,
      qt_doc_prof_iftp_qp INTEGER,
      qt_doc_prof_fic_con INTEGER,
      qt_doc_eja INTEGER,
      qt_doc_eja_fund INTEGER,
      qt_doc_eja_fund_nprof INTEGER,
      qt_doc_eja_fund_ai INTEGER,
      qt_doc_eja_fund_af INTEGER,
      qt_doc_eja_fund_fic INTEGER,
      qt_doc_eja_med INTEGER,
      qt_doc_eja_med_nprof INTEGER,
      qt_doc_eja_med_fic INTEGER,
      qt_doc_eja_med_tec INTEGER,
      qt_doc_esp INTEGER,
      qt_doc_esp_cc INTEGER,
      qt_doc_esp_ce INTEGER,
      qt_doc_bas_fem INTEGER,
      qt_doc_bas_masc INTEGER,
      qt_doc_bas_nd INTEGER,
      qt_doc_bas_branca INTEGER,
      qt_doc_bas_preta INTEGER,
      qt_doc_bas_parda INTEGER,
      qt_doc_bas_amarela INTEGER,
      qt_doc_bas_indigena INTEGER,
      qt_doc_bas_0_24 INTEGER,
      qt_doc_bas_25_29 INTEGER,
      qt_doc_bas_30_39 INTEGER,
      qt_doc_bas_40_49 INTEGER,
      qt_doc_bas_50_54 INTEGER,
      qt_doc_bas_55_59 INTEGER,
      qt_doc_bas_60_mais INTEGER,
      qt_doc_bas_pcd INTEGER,
      qt_doc_bas_zr_urb INTEGER,
      qt_doc_bas_zr_rur INTEGER,
      qt_doc_bas_zr_na INTEGER,
      qt_doc_bas_esco_ef INTEGER,
      qt_doc_bas_esco_em INTEGER,
      qt_doc_bas_esco_sup_grad INTEGER,
      qt_doc_bas_esco_sup_grad_licen INTEGER,
      qt_doc_bas_esco_sup_grad_slicen INTEGER,
      qt_doc_bas_esco_sup_pos_espec INTEGER,
      qt_doc_bas_esco_sup_pos_mestra INTEGER,
      qt_doc_bas_esco_sup_pos_douto INTEGER,
      qt_doc_bas_esco_sup_pos_nenhum INTEGER,
      qt_doc_bas_vinculo_concur INTEGER,
      qt_doc_bas_vinculo_contra INTEGER,
      qt_doc_bas_vinculo_terceir INTEGER,
      qt_doc_bas_vinculo_clt INTEGER,
      qt_doc_bas_docente INTEGER,
      qt_doc_bas_auxiliar INTEGER,
      qt_doc_bas_profi_monitor INTEGER,
      qt_doc_bas_tradutor_libras INTEGER,
      qt_doc_bas_titular_ead INTEGER,
      qt_doc_bas_tutor_aux_ead INTEGER,
      qt_doc_bas_guia_interprete INTEGER,
      qt_doc_bas_apoio_pcd INTEGER,
      qt_doc_bas_instrutor_ep INTEGER,
      qt_doc_bas_espec_cre INTEGER,
      qt_doc_bas_espec_pre_escola INTEGER,
      qt_doc_bas_espec_anos_iniciais INTEGER,
      qt_doc_bas_espec_anos_finais INTEGER,
      qt_doc_bas_espec_ens_medio INTEGER,
      qt_doc_bas_espec_eja INTEGER,
      qt_doc_bas_espec_ed_especial INTEGER,
      qt_doc_bas_espec_bil_surdos INTEGER,
      qt_doc_bas_espec_ed_indigena INTEGER,
      qt_doc_bas_espec_campo INTEGER,
      qt_doc_bas_espec_ambiental INTEGER,
      qt_doc_bas_espec_dir_humanos INTEGER,
      qt_doc_bas_espec_div_sexual INTEGER,
      qt_doc_bas_espec_dir_adolesc INTEGER,
      qt_doc_bas_espec_afro INTEGER,
      qt_doc_bas_espec_gestao INTEGER,
      qt_doc_bas_espec_educ_tic INTEGER,
      qt_doc_bas_espec_outros INTEGER,
      qt_doc_bas_espec_nenhum INTEGER,
      qt_doc_bas_disc_lingua_port INTEGER,
      qt_doc_bas_disc_educ_fisica INTEGER,
      qt_doc_bas_disc_artes INTEGER,
      qt_doc_bas_disc_lingua_ing INTEGER,
      qt_doc_bas_disc_lingua_espa INTEGER,
      qt_doc_bas_disc_lingua_franc INTEGER,
      qt_doc_bas_disc_lingua_outra INTEGER,
      qt_doc_bas_disc_libras INTEGER,
      qt_doc_bas_disc_lingua_indig INTEGER,
      qt_doc_bas_disc_port_seg_lingua INTEGER,
      qt_doc_bas_disc_matematica INTEGER,
      qt_doc_bas_disc_ciencias INTEGER,
      qt_doc_bas_disc_fisica INTEGER,
      qt_doc_bas_disc_quimica INTEGER,
      qt_doc_bas_disc_biologia INTEGER,
      qt_doc_bas_disc_historia INTEGER,
      qt_doc_bas_disc_geografia INTEGER,
      qt_doc_bas_disc_sociologia INTEGER,
      qt_doc_bas_disc_filosofia INTEGER,
      qt_doc_bas_disc_est_sociais INTEGER,
      qt_doc_bas_disc_est_sociais_soci INTEGER,
      qt_doc_bas_disc_info_computacao INTEGER,
      qt_doc_bas_disc_ensino_religioso INTEGER,
      qt_doc_bas_disc_profissiona INTEGER,
      qt_doc_bas_disc_estagio_super INTEGER,
      qt_doc_bas_disc_pedagogicas INTEGER,
      qt_doc_bas_disc_projeto_de_vida INTEGER,
      qt_doc_bas_disc_outras INTEGER,
      qt_doc_bas_libras INTEGER,
      PRIMARY KEY (nu_ano_censo, co_entidade)
  );

  -- Índices para otimização
  CREATE INDEX idx_censo_docentes_co_entidade ON clean.censo_docentes (co_entidade);

  -- Importação dos dados
  COPY clean.censo_docentes (
      nu_ano_censo,
      co_entidade,
      qt_doc_bas,
      qt_doc_inf,
      qt_doc_inf_cre,
      qt_doc_inf_pre,
      qt_doc_fund,
      qt_doc_fund_ai,
      qt_doc_fund_ai_1,
      qt_doc_fund_ai_2,
      qt_doc_fund_ai_3,
      qt_doc_fund_ai_4,
      qt_doc_fund_ai_5,
      qt_doc_fund_ai_multietapa,
      qt_doc_fund_af,
      qt_doc_fund_af_6,
      qt_doc_fund_af_7,
      qt_doc_fund_af_8,
      qt_doc_fund_af_9,
      qt_doc_fund_af_multi,
      qt_doc_fund_af_corrfluxo,
      qt_doc_med,
      qt_doc_med_prop,
      qt_doc_med_prop_1,
      qt_doc_med_prop_2,
      qt_doc_med_prop_3,
      qt_doc_med_prop_4,
      qt_doc_med_prop_ns,
      qt_doc_med_iftp_ct,
      qt_doc_med_iftp_ct_1,
      qt_doc_med_iftp_ct_2,
      qt_doc_med_iftp_ct_3,
      qt_doc_med_iftp_ct_4,
      qt_doc_med_iftp_ct_ns,
      qt_doc_med_iftp_qp,
      qt_doc_med_iftp_qp_1,
      qt_doc_med_iftp_qp_2,
      qt_doc_med_iftp_qp_3,
      qt_doc_med_iftp_qp_4,
      qt_doc_med_iftp_qp_ns,
      qt_doc_med_nm,
      qt_doc_med_nm_1,
      qt_doc_med_nm_2,
      qt_doc_med_nm_3,
      qt_doc_med_nm_4,
      qt_doc_prof,
      qt_doc_prof_tec,
      qt_doc_prof_tec_con,
      qt_doc_prof_tec_subs,
      qt_doc_prof_tec_misto,
      qt_doc_prof_tec_iftp_ct,
      qt_doc_prof_nao_tec,
      qt_doc_prof_iftp_qp,
      qt_doc_prof_fic_con,
      qt_doc_eja,
      qt_doc_eja_fund,
      qt_doc_eja_fund_nprof,
      qt_doc_eja_fund_ai,
      qt_doc_eja_fund_af,
      qt_doc_eja_fund_fic,
      qt_doc_eja_med,
      qt_doc_eja_med_nprof,
      qt_doc_eja_med_fic,
      qt_doc_eja_med_tec,
      qt_doc_esp,
      qt_doc_esp_cc,
      qt_doc_esp_ce,
      qt_doc_bas_fem,
      qt_doc_bas_masc,
      qt_doc_bas_nd,
      qt_doc_bas_branca,
      qt_doc_bas_preta,
      qt_doc_bas_parda,
      qt_doc_bas_amarela,
      qt_doc_bas_indigena,
      qt_doc_bas_0_24,
      qt_doc_bas_25_29,
      qt_doc_bas_30_39,
      qt_doc_bas_40_49,
      qt_doc_bas_50_54,
      qt_doc_bas_55_59,
      qt_doc_bas_60_mais,
      qt_doc_bas_pcd,
      qt_doc_bas_zr_urb,
      qt_doc_bas_zr_rur,
      qt_doc_bas_zr_na,
      qt_doc_bas_esco_ef,
      qt_doc_bas_esco_em,
      qt_doc_bas_esco_sup_grad,
      qt_doc_bas_esco_sup_grad_licen,
      qt_doc_bas_esco_sup_grad_slicen,
      qt_doc_bas_esco_sup_pos_espec,
      qt_doc_bas_esco_sup_pos_mestra,
      qt_doc_bas_esco_sup_pos_douto,
      qt_doc_bas_esco_sup_pos_nenhum,
      qt_doc_bas_vinculo_concur,
      qt_doc_bas_vinculo_contra,
      qt_doc_bas_vinculo_terceir,
      qt_doc_bas_vinculo_clt,
      qt_doc_bas_docente,
      qt_doc_bas_auxiliar,
      qt_doc_bas_profi_monitor,
      qt_doc_bas_tradutor_libras,
      qt_doc_bas_titular_ead,
      qt_doc_bas_tutor_aux_ead,
      qt_doc_bas_guia_interprete,
      qt_doc_bas_apoio_pcd,
      qt_doc_bas_instrutor_ep,
      qt_doc_bas_espec_cre,
      qt_doc_bas_espec_pre_escola,
      qt_doc_bas_espec_anos_iniciais,
      qt_doc_bas_espec_anos_finais,
      qt_doc_bas_espec_ens_medio,
      qt_doc_bas_espec_eja,
      qt_doc_bas_espec_ed_especial,
      qt_doc_bas_espec_bil_surdos,
      qt_doc_bas_espec_ed_indigena,
      qt_doc_bas_espec_campo,
      qt_doc_bas_espec_ambiental,
      qt_doc_bas_espec_dir_humanos,
      qt_doc_bas_espec_div_sexual,
      qt_doc_bas_espec_dir_adolesc,
      qt_doc_bas_espec_afro,
      qt_doc_bas_espec_gestao,
      qt_doc_bas_espec_educ_tic,
      qt_doc_bas_espec_outros,
      qt_doc_bas_espec_nenhum,
      qt_doc_bas_disc_lingua_port,
      qt_doc_bas_disc_educ_fisica,
      qt_doc_bas_disc_artes,
      qt_doc_bas_disc_lingua_ing,
      qt_doc_bas_disc_lingua_espa,
      qt_doc_bas_disc_lingua_franc,
      qt_doc_bas_disc_lingua_outra,
      qt_doc_bas_disc_libras,
      qt_doc_bas_disc_lingua_indig,
      qt_doc_bas_disc_port_seg_lingua,
      qt_doc_bas_disc_matematica,
      qt_doc_bas_disc_ciencias,
      qt_doc_bas_disc_fisica,
      qt_doc_bas_disc_quimica,
      qt_doc_bas_disc_biologia,
      qt_doc_bas_disc_historia,
      qt_doc_bas_disc_geografia,
      qt_doc_bas_disc_sociologia,
      qt_doc_bas_disc_filosofia,
      qt_doc_bas_disc_est_sociais,
      qt_doc_bas_disc_est_sociais_soci,
      qt_doc_bas_disc_info_computacao,
      qt_doc_bas_disc_ensino_religioso,
      qt_doc_bas_disc_profissiona,
      qt_doc_bas_disc_estagio_super,
      qt_doc_bas_disc_pedagogicas,
      qt_doc_bas_disc_projeto_de_vida,
      qt_doc_bas_disc_outras,
      qt_doc_bas_libras
  )
  FROM '/data/Tabela_Docente_2025.csv'
  DELIMITER ';'
  CSV HEADER;

  COMMENT ON TABLE clean.censo_docentes IS 'Docentes do Censo Escolar 2025 por escola (CO_ENTIDADE) e ano';

  COMMENT ON COLUMN clean.censo_docentes.nu_ano_censo IS 'Ano do censo (2025)';
  COMMENT ON COLUMN clean.censo_docentes.co_entidade IS 'Código único da escola (FK para clean.censo_escolas)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas IS 'Total de docentes na educação básica';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_inf IS 'Docentes na educação infantil';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_inf_cre IS 'Docentes em creche';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_inf_pre IS 'Docentes na pré-escola';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund IS 'Docentes no ensino fundamental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai IS 'Docentes nos anos iniciais do fundamental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_1 IS 'Docentes no 1º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_2 IS 'Docentes no 2º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_3 IS 'Docentes no 3º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_4 IS 'Docentes no 4º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_5 IS 'Docentes no 5º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_ai_multietapa IS 'Docentes em turmas multietapa nos anos iniciais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af IS 'Docentes nos anos finais do fundamental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_6 IS 'Docentes no 6º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_7 IS 'Docentes no 7º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_8 IS 'Docentes no 8º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_9 IS 'Docentes no 9º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_multi IS 'Docentes em turmas multietapa nos anos finais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_fund_af_corrfluxo IS 'Docentes em turmas de correção de fluxo nos anos finais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med IS 'Docentes no ensino médio';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop IS 'Docentes no ensino médio - proposta pedagógica';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop_1 IS 'Docentes na 1ª série do médio (proposta)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop_2 IS 'Docentes na 2ª série do médio (proposta)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop_3 IS 'Docentes na 3ª série do médio (proposta)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop_4 IS 'Docentes na 4ª série do médio (proposta)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_prop_ns IS 'Docentes no médio - série não especificada (proposta)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct IS 'Docentes no médio integrado à formação técnica - curso técnico';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct_1 IS 'Docentes no IFTP/CT - 1ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct_2 IS 'Docentes no IFTP/CT - 2ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct_3 IS 'Docentes no IFTP/CT - 3ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct_4 IS 'Docentes no IFTP/CT - 4ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_ct_ns IS 'Docentes no IFTP/CT - série não especificada';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp IS 'Docentes no médio integrado à formação técnica - qualificação profissional';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp_1 IS 'Docentes no IFTP/QP - 1ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp_2 IS 'Docentes no IFTP/QP - 2ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp_3 IS 'Docentes no IFTP/QP - 3ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp_4 IS 'Docentes no IFTP/QP - 4ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_iftp_qp_ns IS 'Docentes no IFTP/QP - série não especificada';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_nm IS 'Docentes no ensino médio normal/magistério';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_nm_1 IS 'Docentes no normal/magistério - 1ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_nm_2 IS 'Docentes no normal/magistério - 2ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_nm_3 IS 'Docentes no normal/magistério - 3ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_med_nm_4 IS 'Docentes no normal/magistério - 4ª série';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof IS 'Docentes na educação profissional (total)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_tec IS 'Docentes na educação profissional técnica';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_tec_con IS 'Docentes no técnico concomitante';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_tec_subs IS 'Docentes no técnico subsequente';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_tec_misto IS 'Docentes no técnico misto';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_tec_iftp_ct IS 'Docentes no técnico IFTP curso técnico';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_nao_tec IS 'Docentes na formação profissional não técnica';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_iftp_qp IS 'Docentes profissional IFTP qualificação';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_prof_fic_con IS 'Docentes no FIC concomitante';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja IS 'Docentes na EJA (Educação de Jovens e Adultos)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_fund IS 'Docentes na EJA fundamental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_fund_nprof IS 'Docentes na EJA fundamental não profissionalizante';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_fund_ai IS 'Docentes na EJA fundamental anos iniciais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_fund_af IS 'Docentes na EJA fundamental anos finais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_fund_fic IS 'Docentes na EJA fundamental FIC';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_med IS 'Docentes na EJA médio';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_med_nprof IS 'Docentes na EJA médio não profissionalizante';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_med_fic IS 'Docentes na EJA médio FIC';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_eja_med_tec IS 'Docentes na EJA médio técnico';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_esp IS 'Docentes na educação especial (total)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_esp_cc IS 'Docentes em classes comuns (inclusão) na educação especial';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_esp_ce IS 'Docentes em classes exclusivas (AEE) na educação especial';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_fem IS 'Docentes do sexo feminino (educação básica)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_masc IS 'Docentes do sexo masculino';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_nd IS 'Docentes com sexo não declarado';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_branca IS 'Docentes de cor/raça branca';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_preta IS 'Docentes de cor/raça preta';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_parda IS 'Docentes de cor/raça parda';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_amarela IS 'Docentes de cor/raça amarela';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_indigena IS 'Docentes de cor/raça indígena';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_0_24 IS 'Docentes com idade até 24 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_25_29 IS 'Docentes com idade de 25 a 29 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_30_39 IS 'Docentes com idade de 30 a 39 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_40_49 IS 'Docentes com idade de 40 a 49 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_50_54 IS 'Docentes com idade de 50 a 54 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_55_59 IS 'Docentes com idade de 55 a 59 anos';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_60_mais IS 'Docentes com idade de 60 anos ou mais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_pcd IS 'Docentes com deficiência (PcD)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_zr_urb IS 'Docentes atuando em zona urbana';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_zr_rur IS 'Docentes atuando em zona rural';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_zr_na IS 'Docentes com zona não aplicável';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_ef IS 'Docentes com escolaridade até ensino fundamental';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_em IS 'Docentes com escolaridade ensino médio';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_grad IS 'Docentes com ensino superior (graduação)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_grad_licen IS 'Docentes com licenciatura';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_grad_slicen IS 'Docentes com graduação sem licenciatura';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_pos_espec IS 'Docentes com pós-graduação especialização';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_pos_mestra IS 'Docentes com mestrado';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_pos_douto IS 'Docentes com doutorado';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_esco_sup_pos_nenhum IS 'Docentes sem pós-graduação';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_vinculo_concur IS 'Docentes com vínculo concursado/efetivo';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_vinculo_contra IS 'Docentes contratados temporariamente';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_vinculo_terceir IS 'Docentes terceirizados';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_vinculo_clt IS 'Docentes com vínculo CLT';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_docente IS 'Docentes com função docente (regência de classe)';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_auxiliar IS 'Docentes auxiliares/assistentes';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_profi_monitor IS 'Docentes profissionais/monitores';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_tradutor_libras IS 'Docentes tradutores/intérpretes de Libras';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_titular_ead IS 'Docentes titulares em EAD';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_tutor_aux_ead IS 'Docentes tutores/auxiliares em EAD';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_guia_interprete IS 'Docentes guia-intérpretes';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_apoio_pcd IS 'Docentes de apoio a PcD';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_instrutor_ep IS 'Docentes instrutores de educação profissional';
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
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_port IS 'Docentes que lecionam Língua Portuguesa';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_educ_fisica IS 'Docentes que lecionam Educação Física';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_artes IS 'Docentes que lecionam Artes';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_ing IS 'Docentes que lecionam Língua Inglesa';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_espa IS 'Docentes que lecionam Língua Espanhola';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_franc IS 'Docentes que lecionam Língua Francesa';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_outra IS 'Docentes que lecionam outra língua';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_libras IS 'Docentes que lecionam Libras';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_lingua_indig IS 'Docentes que lecionam Língua Indígena';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_port_seg_lingua IS 'Docentes que lecionam Português como segunda língua';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_matematica IS 'Docentes que lecionam Matemática';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_ciencias IS 'Docentes que lecionam Ciências';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_fisica IS 'Docentes que lecionam Física';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_quimica IS 'Docentes que lecionam Química';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_biologia IS 'Docentes que lecionam Biologia';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_historia IS 'Docentes que lecionam História';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_geografia IS 'Docentes que lecionam Geografia';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_sociologia IS 'Docentes que lecionam Sociologia';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_filosofia IS 'Docentes que lecionam Filosofia';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_est_sociais IS 'Docentes que lecionam Estudos Sociais';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_est_sociais_soci IS 'Docentes que lecionam Estudos Sociais e Sociologia';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_info_computacao IS 'Docentes que lecionam Informática/Computação';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_ensino_religioso IS 'Docentes que lecionam Ensino Religioso';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_profissiona IS 'Docentes que lecionam disciplinas profissionalizantes';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_estagio_super IS 'Docentes que orientam estágio supervisionado';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_pedagogicas IS 'Docentes que lecionam disciplinas pedagógicas';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_projeto_de_vida IS 'Docentes que lecionam Projeto de Vida';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_disc_outras IS 'Docentes que lecionam outras disciplinas';
  COMMENT ON COLUMN clean.censo_docentes.qt_doc_bas_libras IS 'Docentes com proficiência em Libras';
COMMIT;
