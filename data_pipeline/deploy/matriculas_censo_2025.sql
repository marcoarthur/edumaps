-- Deploy edumaps:matriculas_censo_2025 to pg
-- requires: censo_escolar_2025

BEGIN;

  CREATE TABLE clean.censo_matriculas (
      nu_ano_censo INTEGER NOT NULL,
      co_entidade BIGINT NOT NULL,
      qt_mat_bas INTEGER,
      qt_mat_inf INTEGER,
      qt_mat_inf_cre INTEGER,
      qt_mat_inf_pre INTEGER,
      qt_mat_fund INTEGER,
      qt_mat_fund_ai INTEGER,
      qt_mat_fund_ai_1 INTEGER,
      qt_mat_fund_ai_2 INTEGER,
      qt_mat_fund_ai_3 INTEGER,
      qt_mat_fund_ai_4 INTEGER,
      qt_mat_fund_ai_5 INTEGER,
      qt_mat_fund_af INTEGER,
      qt_mat_fund_af_6 INTEGER,
      qt_mat_fund_af_7 INTEGER,
      qt_mat_fund_af_8 INTEGER,
      qt_mat_fund_af_9 INTEGER,
      qt_mat_med INTEGER,
      qt_mat_med_prop INTEGER,
      qt_mat_med_prop_1 INTEGER,
      qt_mat_med_prop_2 INTEGER,
      qt_mat_med_prop_3 INTEGER,
      qt_mat_med_prop_4 INTEGER,
      qt_mat_med_prop_ns INTEGER,
      qt_mat_med_iftp_ct INTEGER,
      qt_mat_med_iftp_ct_1 INTEGER,
      qt_mat_med_iftp_ct_2 INTEGER,
      qt_mat_med_iftp_ct_3 INTEGER,
      qt_mat_med_iftp_ct_4 INTEGER,
      qt_mat_med_iftp_ct_ns INTEGER,
      qt_mat_med_iftp_qp INTEGER,
      qt_mat_med_iftp_qp_1 INTEGER,
      qt_mat_med_iftp_qp_2 INTEGER,
      qt_mat_med_iftp_qp_3 INTEGER,
      qt_mat_med_iftp_qp_4 INTEGER,
      qt_mat_med_iftp_qp_ns INTEGER,
      qt_mat_med_nm INTEGER,
      qt_mat_med_nm_1 INTEGER,
      qt_mat_med_nm_2 INTEGER,
      qt_mat_med_nm_3 INTEGER,
      qt_mat_med_nm_4 INTEGER,
      qt_mat_med_ifa INTEGER,
      qt_mat_med_ifa_ling INTEGER,
      qt_mat_med_ifa_ling_mt INTEGER,
      qt_mat_med_ifa_ling_otme INTEGER,
      qt_mat_med_ifa_ling_oe INTEGER,
      qt_mat_med_ifa_mate INTEGER,
      qt_mat_med_ifa_mate_mt INTEGER,
      qt_mat_med_ifa_mate_otme INTEGER,
      qt_mat_med_ifa_mate_oe INTEGER,
      qt_mat_med_ifa_cienc INTEGER,
      qt_mat_med_ifa_cienc_mt INTEGER,
      qt_mat_med_ifa_cienc_otme INTEGER,
      qt_mat_med_ifa_cienc_oe INTEGER,
      qt_mat_med_ifa_huma INTEGER,
      qt_mat_med_ifa_huma_mt INTEGER,
      qt_mat_med_ifa_huma_otme INTEGER,
      qt_mat_med_ifa_huma_oe INTEGER,
      qt_mat_med_arti_iftp_ct INTEGER,
      qt_mat_med_arti_iftp_ct_mt INTEGER,
      qt_mat_med_arti_iftp_ct_otme INTEGER,
      qt_mat_med_arti_iftp_ct_oe INTEGER,
      qt_mat_med_arti_iftp_qp INTEGER,
      qt_mat_med_arti_iftp_qp_mt INTEGER,
      qt_mat_med_arti_iftp_qp_otme INTEGER,
      qt_mat_med_arti_iftp_qp_oe INTEGER,
      qt_mat_prof INTEGER,
      qt_mat_prof_tec INTEGER,
      qt_mat_prof_tec_con INTEGER,
      qt_mat_prof_tec_subs INTEGER,
      qt_mat_prof_tec_iftp_ct INTEGER,
      qt_mat_prof_nao_tec INTEGER,
      qt_mat_prof_iftp_qp INTEGER,
      qt_mat_prof_fic_con INTEGER,
      qt_mat_eja INTEGER,
      qt_mat_eja_fund INTEGER,
      qt_mat_eja_fund_nprof INTEGER,
      qt_mat_eja_fund_ai INTEGER,
      qt_mat_eja_fund_af INTEGER,
      qt_mat_eja_fund_fic INTEGER,
      qt_mat_eja_med INTEGER,
      qt_mat_eja_med_nprof INTEGER,
      qt_mat_eja_med_fic INTEGER,
      qt_mat_eja_med_tec INTEGER,
      qt_mat_esp INTEGER,
      qt_mat_esp_inf INTEGER,
      qt_mat_esp_inf_cre INTEGER,
      qt_mat_esp_inf_pre INTEGER,
      qt_mat_esp_fund INTEGER,
      qt_mat_esp_fund_ai INTEGER,
      qt_mat_esp_fund_af INTEGER,
      qt_mat_esp_med INTEGER,
      qt_mat_esp_prof INTEGER,
      qt_mat_esp_prof_tec INTEGER,
      qt_mat_esp_eja INTEGER,
      qt_mat_esp_eja_fund INTEGER,
      qt_mat_esp_eja_med INTEGER,
      qt_mat_esp_cc INTEGER,
      qt_mat_esp_cc_inf INTEGER,
      qt_mat_esp_cc_inf_cre INTEGER,
      qt_mat_esp_cc_inf_pre INTEGER,
      qt_mat_esp_cc_fund INTEGER,
      qt_mat_esp_cc_fund_ai INTEGER,
      qt_mat_esp_cc_fund_af INTEGER,
      qt_mat_esp_cc_med INTEGER,
      qt_mat_esp_cc_prof INTEGER,
      qt_mat_esp_cc_prof_tec INTEGER,
      qt_mat_esp_cc_eja INTEGER,
      qt_mat_esp_cc_eja_fund INTEGER,
      qt_mat_esp_cc_eja_med INTEGER,
      qt_mat_esp_ce INTEGER,
      qt_mat_esp_ce_inf INTEGER,
      qt_mat_esp_ce_inf_cre INTEGER,
      qt_mat_esp_ce_inf_pre INTEGER,
      qt_mat_esp_ce_fund INTEGER,
      qt_mat_esp_ce_fund_ai INTEGER,
      qt_mat_esp_ce_fund_af INTEGER,
      qt_mat_esp_ce_med INTEGER,
      qt_mat_esp_ce_prof INTEGER,
      qt_mat_esp_ce_prof_tec INTEGER,
      qt_mat_esp_ce_eja INTEGER,
      qt_mat_esp_ce_eja_fund INTEGER,
      qt_mat_esp_ce_eja_med INTEGER,
      qt_mat_bas_fem INTEGER,
      qt_mat_bas_masc INTEGER,
      qt_mat_bas_nd INTEGER,
      qt_mat_bas_branca INTEGER,
      qt_mat_bas_preta INTEGER,
      qt_mat_bas_parda INTEGER,
      qt_mat_bas_amarela INTEGER,
      qt_mat_bas_indigena INTEGER,
      qt_mat_bas_0_3 INTEGER,
      qt_mat_bas_4_5 INTEGER,
      qt_mat_bas_6_10 INTEGER,
      qt_mat_bas_11_14 INTEGER,
      qt_mat_bas_15_17 INTEGER,
      qt_mat_bas_18_mais INTEGER,
      qt_mat_bas_0_3_ref_31_03 INTEGER,
      qt_mat_bas_4_5_ref_31_03 INTEGER,
      qt_mat_bas_6_10_ref_31_03 INTEGER,
      qt_mat_bas_11_14_ref_31_03 INTEGER,
      qt_mat_bas_15_17_ref_31_03 INTEGER,
      qt_mat_bas_18_mais_ref_31_03 INTEGER,
      qt_mat_bas_d INTEGER,
      qt_mat_bas_dm INTEGER,
      qt_mat_bas_dv INTEGER,
      qt_mat_bas_n INTEGER,
      qt_mat_bas_ead INTEGER,
      qt_mat_inf_cre_d INTEGER,
      qt_mat_inf_cre_dm INTEGER,
      qt_mat_inf_cre_dv INTEGER,
      qt_mat_inf_cre_n INTEGER,
      qt_mat_inf_pre_d INTEGER,
      qt_mat_inf_pre_dm INTEGER,
      qt_mat_inf_pre_dv INTEGER,
      qt_mat_inf_pre_n INTEGER,
      qt_mat_fund_d INTEGER,
      qt_mat_fund_dm INTEGER,
      qt_mat_fund_dv INTEGER,
      qt_mat_fund_n INTEGER,
      qt_mat_fund_ai_d INTEGER,
      qt_mat_fund_ai_dm INTEGER,
      qt_mat_fund_ai_dv INTEGER,
      qt_mat_fund_ai_n INTEGER,
      qt_mat_fund_af_d INTEGER,
      qt_mat_fund_af_dm INTEGER,
      qt_mat_fund_af_dv INTEGER,
      qt_mat_fund_af_n INTEGER,
      qt_mat_med_d INTEGER,
      qt_mat_med_dm INTEGER,
      qt_mat_med_dv INTEGER,
      qt_mat_med_n INTEGER,
      qt_mat_med_ead INTEGER,
      qt_mat_prof_d INTEGER,
      qt_mat_prof_dm INTEGER,
      qt_mat_prof_dv INTEGER,
      qt_mat_prof_n INTEGER,
      qt_mat_prof_ead INTEGER,
      qt_mat_prof_tec_d INTEGER,
      qt_mat_prof_tec_dm INTEGER,
      qt_mat_prof_tec_dv INTEGER,
      qt_mat_prof_tec_n INTEGER,
      qt_mat_prof_tec_ead INTEGER,
      qt_mat_eja_d INTEGER,
      qt_mat_eja_dm INTEGER,
      qt_mat_eja_dv INTEGER,
      qt_mat_eja_n INTEGER,
      qt_mat_eja_ead INTEGER,
      qt_mat_eja_fund_d INTEGER,
      qt_mat_eja_fund_dm INTEGER,
      qt_mat_eja_fund_dv INTEGER,
      qt_mat_eja_fund_n INTEGER,
      qt_mat_eja_fund_ead INTEGER,
      qt_mat_eja_med_d INTEGER,
      qt_mat_eja_med_dm INTEGER,
      qt_mat_eja_med_dv INTEGER,
      qt_mat_eja_med_n INTEGER,
      qt_mat_eja_med_ead INTEGER,
      qt_mat_esp_d INTEGER,
      qt_mat_esp_dm INTEGER,
      qt_mat_esp_dv INTEGER,
      qt_mat_esp_n INTEGER,
      qt_mat_esp_ead INTEGER,
      qt_mat_esp_cc_d INTEGER,
      qt_mat_esp_cc_dm INTEGER,
      qt_mat_esp_cc_dv INTEGER,
      qt_mat_esp_cc_n INTEGER,
      qt_mat_esp_cc_ead INTEGER,
      qt_mat_esp_ce_d INTEGER,
      qt_mat_esp_ce_dm INTEGER,
      qt_mat_esp_ce_dv INTEGER,
      qt_mat_esp_ce_n INTEGER,
      qt_mat_esp_ce_ead INTEGER,
      qt_mat_bas_int INTEGER,
      qt_mat_inf_int INTEGER,
      qt_mat_inf_cre_int INTEGER,
      qt_mat_inf_pre_int INTEGER,
      qt_mat_fund_int INTEGER,
      qt_mat_fund_ai_int INTEGER,
      qt_mat_fund_af_int INTEGER,
      qt_mat_med_int INTEGER,
      qt_mat_prof_int INTEGER,
      qt_mat_prof_tec_int INTEGER,
      qt_mat_eja_int INTEGER,
      qt_mat_eja_fund_int INTEGER,
      qt_mat_eja_med_int INTEGER,
      qt_mat_esp_int INTEGER,
      qt_mat_esp_cc_int INTEGER,
      qt_mat_esp_ce_int INTEGER,
      qt_mat_bas_libras INTEGER,
      qt_mat_zr_urb INTEGER,
      qt_mat_zr_rur INTEGER,
      qt_mat_zr_na INTEGER,
      qt_transp_publico INTEGER,
      qt_transp_resp_est INTEGER,
      qt_transp_resp_mun INTEGER,
      PRIMARY KEY (nu_ano_censo, co_entidade)
  );

  -- Comentários nas colunas (explicativos baseados no nome)
  COMMENT ON TABLE clean.censo_matriculas IS 'Matrículas do Censo Escolar 2025 por escola (CO_ENTIDADE) e ano';

  COMMENT ON COLUMN clean.censo_matriculas.nu_ano_censo IS 'Ano do censo (2025)';
  COMMENT ON COLUMN clean.censo_matriculas.co_entidade IS 'Código único da escola (mesmo da tabela clean.censo_escolas)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas IS 'Total de matrículas na educação básica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf IS 'Matrículas na educação infantil';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre IS 'Matrículas em creche (educação infantil)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre IS 'Matrículas na pré-escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund IS 'Matrículas no ensino fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai IS 'Matrículas nos anos iniciais do fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_1 IS '1º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_2 IS '2º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_3 IS '3º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_4 IS '4º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_5 IS '5º ano do fundamental (anos iniciais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af IS 'Matrículas nos anos finais do fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_6 IS '6º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_7 IS '7º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_8 IS '8º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_9 IS '9º ano do fundamental (anos finais)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med IS 'Matrículas no ensino médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop IS 'Ensino médio – proposta pedagógica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop_1 IS 'Ensino médio – 1ª série (proposta)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop_2 IS 'Ensino médio – 2ª série (proposta)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop_3 IS 'Ensino médio – 3ª série (proposta)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop_4 IS 'Ensino médio – 4ª série (proposta)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_prop_ns IS 'Ensino médio – série não especificada';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct IS 'Ensino médio integrado à formação técnica – curso técnico';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct_1 IS 'IFTP/CT – 1ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct_2 IS 'IFTP/CT – 2ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct_3 IS 'IFTP/CT – 3ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct_4 IS 'IFTP/CT – 4ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_ct_ns IS 'IFTP/CT – série não especificada';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp IS 'Ensino médio integrado à formação técnica – qualificação profissional';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp_1 IS 'IFTP/QP – 1ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp_2 IS 'IFTP/QP – 2ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp_3 IS 'IFTP/QP – 3ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp_4 IS 'IFTP/QP – 4ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_iftp_qp_ns IS 'IFTP/QP – série não especificada';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_nm IS 'Ensino médio – normal/magistério';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_nm_1 IS 'Normal/magistério – 1ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_nm_2 IS 'Normal/magistério – 2ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_nm_3 IS 'Normal/magistério – 3ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_nm_4 IS 'Normal/magistério – 4ª série';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa IS 'Ensino médio – itinerários formativos articulados (IFA)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_ling IS 'IFA – Linguagens';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_ling_mt IS 'IFA/Linguagens – ofertado em mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_ling_otme IS 'IFA/Linguagens – ofertado em um turno (manhã/tarde) em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_ling_oe IS 'IFA/Linguagens – ofertado em uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_mate IS 'IFA – Matemática';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_mate_mt IS 'IFA/Matemática – mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_mate_otme IS 'IFA/Matemática – um turno em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_mate_oe IS 'IFA/Matemática – uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_cienc IS 'IFA – Ciências da natureza';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_cienc_mt IS 'IFA/Ciências – mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_cienc_otme IS 'IFA/Ciências – um turno em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_cienc_oe IS 'IFA/Ciências – uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_huma IS 'IFA – Ciências humanas';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_huma_mt IS 'IFA/Humanas – mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_huma_otme IS 'IFA/Humanas – um turno em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ifa_huma_oe IS 'IFA/Humanas – uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_ct IS 'Articulação com IFTP – curso técnico';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_ct_mt IS 'Articulação IFTP/CT – mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_ct_otme IS 'Articulação IFTP/CT – um turno em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_ct_oe IS 'Articulação IFTP/CT – uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_qp IS 'Articulação com IFTP – qualificação profissional';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_qp_mt IS 'Articulação IFTP/QP – mais de um turno';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_qp_otme IS 'Articulação IFTP/QP – um turno em mais de uma escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_arti_iftp_qp_oe IS 'Articulação IFTP/QP – uma única escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof IS 'Matrículas na educação profissional (total)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec IS 'Educação profissional técnica (subsequente / concomitante)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_con IS 'Técnico – concomitante';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_subs IS 'Técnico – subsequente';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_iftp_ct IS 'Técnico – IFTP curso técnico';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_nao_tec IS 'Formação profissional não técnica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_iftp_qp IS 'Profissional – IFTP qualificação';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_fic_con IS 'FIC (Formação Inicial Continuada) concomitante';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja IS 'Matrículas na EJA (Educação de Jovens e Adultos)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund IS 'EJA – ensino fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_nprof IS 'EJA fundamental – não profissionalizante';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_ai IS 'EJA fundamental – anos iniciais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_af IS 'EJA fundamental – anos finais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_fic IS 'EJA fundamental – FIC';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med IS 'EJA – ensino médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_nprof IS 'EJA médio – não profissionalizante';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_fic IS 'EJA médio – FIC';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_tec IS 'EJA médio – técnico';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp IS 'Matrículas na educação especial (total)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_inf IS 'Especial – educação infantil';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_inf_cre IS 'Especial – creche';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_inf_pre IS 'Especial – pré-escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_fund IS 'Especial – ensino fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_fund_ai IS 'Especial – fundamental anos iniciais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_fund_af IS 'Especial – fundamental anos finais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_med IS 'Especial – ensino médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_prof IS 'Especial – educação profissional';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_prof_tec IS 'Especial – profissional técnica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_eja IS 'Especial – EJA';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_eja_fund IS 'Especial – EJA fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_eja_med IS 'Especial – EJA médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc IS 'Especial – classes comuns (inclusão)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_inf IS 'Classes comuns – educação infantil';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_inf_cre IS 'Classes comuns – creche';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_inf_pre IS 'Classes comuns – pré-escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_fund IS 'Classes comuns – ensino fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_fund_ai IS 'Classes comuns – fundamental anos iniciais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_fund_af IS 'Classes comuns – fundamental anos finais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_med IS 'Classes comuns – ensino médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_prof IS 'Classes comuns – educação profissional';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_prof_tec IS 'Classes comuns – profissional técnica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_eja IS 'Classes comuns – EJA';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_eja_fund IS 'Classes comuns – EJA fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_eja_med IS 'Classes comuns – EJA médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce IS 'Especial – classes exclusivas (AEE)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_inf IS 'Classes exclusivas – educação infantil';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_inf_cre IS 'Classes exclusivas – creche';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_inf_pre IS 'Classes exclusivas – pré-escola';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_fund IS 'Classes exclusivas – ensino fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_fund_ai IS 'Classes exclusivas – fundamental anos iniciais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_fund_af IS 'Classes exclusivas – fundamental anos finais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_med IS 'Classes exclusivas – ensino médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_prof IS 'Classes exclusivas – educação profissional';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_prof_tec IS 'Classes exclusivas – profissional técnica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_eja IS 'Classes exclusivas – EJA';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_eja_fund IS 'Classes exclusivas – EJA fundamental';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_eja_med IS 'Classes exclusivas – EJA médio';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_fem IS 'Educação básica – sexo feminino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_masc IS 'Educação básica – sexo masculino';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_nd IS 'Educação básica – sexo não declarado';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_branca IS 'Raça/cor – branca';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_preta IS 'Raça/cor – preta';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_parda IS 'Raça/cor – parda';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_amarela IS 'Raça/cor – amarela';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_indigena IS 'Raça/cor – indígena';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_0_3 IS 'Idade 0 a 3 anos';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_4_5 IS 'Idade 4 a 5 anos';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_6_10 IS 'Idade 6 a 10 anos';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_11_14 IS 'Idade 11 a 14 anos';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_15_17 IS 'Idade 15 a 17 anos';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_18_mais IS 'Idade 18 anos ou mais';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_0_3_ref_31_03 IS 'Idade 0-3 anos (referência 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_4_5_ref_31_03 IS 'Idade 4-5 anos (ref. 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_6_10_ref_31_03 IS 'Idade 6-10 anos (ref. 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_11_14_ref_31_03 IS 'Idade 11-14 anos (ref. 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_15_17_ref_31_03 IS 'Idade 15-17 anos (ref. 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_18_mais_ref_31_03 IS 'Idade 18+ anos (ref. 31/03)';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_d IS 'Deficiência – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dm IS 'Deficiência – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_dv IS 'Deficiência – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_n IS 'Deficiência – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_ead IS 'Educação básica – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_d IS 'Creche – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dm IS 'Creche – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_dv IS 'Creche – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_n IS 'Creche – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_d IS 'Pré‑escola – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dm IS 'Pré‑escola – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_dv IS 'Pré‑escola – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_n IS 'Pré‑escola – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_d IS 'Fundamental – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dm IS 'Fundamental – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_dv IS 'Fundamental – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_n IS 'Fundamental – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_d IS 'Fundamental anos iniciais – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dm IS 'Fundamental anos iniciais – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_dv IS 'Fundamental anos iniciais – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_n IS 'Fundamental anos iniciais – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_d IS 'Fundamental anos finais – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dm IS 'Fundamental anos finais – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_dv IS 'Fundamental anos finais – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_n IS 'Fundamental anos finais – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_d IS 'Ensino médio – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dm IS 'Ensino médio – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_dv IS 'Ensino médio – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_n IS 'Ensino médio – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_ead IS 'Ensino médio – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_d IS 'Profissional – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dm IS 'Profissional – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_dv IS 'Profissional – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_n IS 'Profissional – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_ead IS 'Profissional – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_d IS 'Profissional técnica – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dm IS 'Profissional técnica – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_dv IS 'Profissional técnica – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_n IS 'Profissional técnica – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_ead IS 'Profissional técnica – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_d IS 'EJA – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dm IS 'EJA – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_dv IS 'EJA – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_n IS 'EJA – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_ead IS 'EJA – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_d IS 'EJA fundamental – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dm IS 'EJA fundamental – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_dv IS 'EJA fundamental – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_n IS 'EJA fundamental – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_ead IS 'EJA fundamental – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_d IS 'EJA médio – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dm IS 'EJA médio – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_dv IS 'EJA médio – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_n IS 'EJA médio – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_ead IS 'EJA médio – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_d IS 'Educação especial – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dm IS 'Educação especial – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_dv IS 'Educação especial – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_n IS 'Educação especial – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ead IS 'Educação especial – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_d IS 'Classe comum – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dm IS 'Classe comum – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_dv IS 'Classe comum – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_n IS 'Classe comum – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_ead IS 'Classe comum – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_d IS 'Classe exclusiva – Deficiência';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dm IS 'Classe exclusiva – Deficiência múltipla';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_dv IS 'Classe exclusiva – Deficiência visual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_n IS 'Classe exclusiva – Não se aplica';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_ead IS 'Classe exclusiva – EAD';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_int IS 'Educação básica – período integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_int IS 'Educação infantil – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_cre_int IS 'Creche – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_inf_pre_int IS 'Pré‑escola – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_int IS 'Fundamental – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_ai_int IS 'Fundamental anos iniciais – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_fund_af_int IS 'Fundamental anos finais – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_med_int IS 'Ensino médio – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_int IS 'Profissional – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_prof_tec_int IS 'Profissional técnica – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_int IS 'EJA – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_fund_int IS 'EJA fundamental – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_eja_med_int IS 'EJA médio – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_int IS 'Educação especial – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_cc_int IS 'Classe comum – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_esp_ce_int IS 'Classe exclusiva – integral';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_bas_libras IS 'Educação básica – Libras';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_zr_urb IS 'Localização – urbana';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_zr_rur IS 'Localização – rural';
  COMMENT ON COLUMN clean.censo_matriculas.qt_mat_zr_na IS 'Localização – não aplicável';
  COMMENT ON COLUMN clean.censo_matriculas.qt_transp_publico IS 'Transporte público – alunos que utilizam';
  COMMENT ON COLUMN clean.censo_matriculas.qt_transp_resp_est IS 'Transporte – responsabilidade estadual';
  COMMENT ON COLUMN clean.censo_matriculas.qt_transp_resp_mun IS 'Transporte – responsabilidade municipal';

  -- Se desejar, adicione uma chave estrangeira para referenciar clean.censo_escolas (opcional)
  -- ALTER TABLE clean.censo_matriculas ADD CONSTRAINT fk_censo_matriculas_co_entidade
  --   FOREIGN KEY (co_entidade) REFERENCES clean.censo_escolas(co_entidade);

  -- Importação dos dados do CSV
  COPY clean.censo_matriculas (
      nu_ano_censo,
      co_entidade,
      qt_mat_bas,
      qt_mat_inf,
      qt_mat_inf_cre,
      qt_mat_inf_pre,
      qt_mat_fund,
      qt_mat_fund_ai,
      qt_mat_fund_ai_1,
      qt_mat_fund_ai_2,
      qt_mat_fund_ai_3,
      qt_mat_fund_ai_4,
      qt_mat_fund_ai_5,
      qt_mat_fund_af,
      qt_mat_fund_af_6,
      qt_mat_fund_af_7,
      qt_mat_fund_af_8,
      qt_mat_fund_af_9,
      qt_mat_med,
      qt_mat_med_prop,
      qt_mat_med_prop_1,
      qt_mat_med_prop_2,
      qt_mat_med_prop_3,
      qt_mat_med_prop_4,
      qt_mat_med_prop_ns,
      qt_mat_med_iftp_ct,
      qt_mat_med_iftp_ct_1,
      qt_mat_med_iftp_ct_2,
      qt_mat_med_iftp_ct_3,
      qt_mat_med_iftp_ct_4,
      qt_mat_med_iftp_ct_ns,
      qt_mat_med_iftp_qp,
      qt_mat_med_iftp_qp_1,
      qt_mat_med_iftp_qp_2,
      qt_mat_med_iftp_qp_3,
      qt_mat_med_iftp_qp_4,
      qt_mat_med_iftp_qp_ns,
      qt_mat_med_nm,
      qt_mat_med_nm_1,
      qt_mat_med_nm_2,
      qt_mat_med_nm_3,
      qt_mat_med_nm_4,
      qt_mat_med_ifa,
      qt_mat_med_ifa_ling,
      qt_mat_med_ifa_ling_mt,
      qt_mat_med_ifa_ling_otme,
      qt_mat_med_ifa_ling_oe,
      qt_mat_med_ifa_mate,
      qt_mat_med_ifa_mate_mt,
      qt_mat_med_ifa_mate_otme,
      qt_mat_med_ifa_mate_oe,
      qt_mat_med_ifa_cienc,
      qt_mat_med_ifa_cienc_mt,
      qt_mat_med_ifa_cienc_otme,
      qt_mat_med_ifa_cienc_oe,
      qt_mat_med_ifa_huma,
      qt_mat_med_ifa_huma_mt,
      qt_mat_med_ifa_huma_otme,
      qt_mat_med_ifa_huma_oe,
      qt_mat_med_arti_iftp_ct,
      qt_mat_med_arti_iftp_ct_mt,
      qt_mat_med_arti_iftp_ct_otme,
      qt_mat_med_arti_iftp_ct_oe,
      qt_mat_med_arti_iftp_qp,
      qt_mat_med_arti_iftp_qp_mt,
      qt_mat_med_arti_iftp_qp_otme,
      qt_mat_med_arti_iftp_qp_oe,
      qt_mat_prof,
      qt_mat_prof_tec,
      qt_mat_prof_tec_con,
      qt_mat_prof_tec_subs,
      qt_mat_prof_tec_iftp_ct,
      qt_mat_prof_nao_tec,
      qt_mat_prof_iftp_qp,
      qt_mat_prof_fic_con,
      qt_mat_eja,
      qt_mat_eja_fund,
      qt_mat_eja_fund_nprof,
      qt_mat_eja_fund_ai,
      qt_mat_eja_fund_af,
      qt_mat_eja_fund_fic,
      qt_mat_eja_med,
      qt_mat_eja_med_nprof,
      qt_mat_eja_med_fic,
      qt_mat_eja_med_tec,
      qt_mat_esp,
      qt_mat_esp_inf,
      qt_mat_esp_inf_cre,
      qt_mat_esp_inf_pre,
      qt_mat_esp_fund,
      qt_mat_esp_fund_ai,
      qt_mat_esp_fund_af,
      qt_mat_esp_med,
      qt_mat_esp_prof,
      qt_mat_esp_prof_tec,
      qt_mat_esp_eja,
      qt_mat_esp_eja_fund,
      qt_mat_esp_eja_med,
      qt_mat_esp_cc,
      qt_mat_esp_cc_inf,
      qt_mat_esp_cc_inf_cre,
      qt_mat_esp_cc_inf_pre,
      qt_mat_esp_cc_fund,
      qt_mat_esp_cc_fund_ai,
      qt_mat_esp_cc_fund_af,
      qt_mat_esp_cc_med,
      qt_mat_esp_cc_prof,
      qt_mat_esp_cc_prof_tec,
      qt_mat_esp_cc_eja,
      qt_mat_esp_cc_eja_fund,
      qt_mat_esp_cc_eja_med,
      qt_mat_esp_ce,
      qt_mat_esp_ce_inf,
      qt_mat_esp_ce_inf_cre,
      qt_mat_esp_ce_inf_pre,
      qt_mat_esp_ce_fund,
      qt_mat_esp_ce_fund_ai,
      qt_mat_esp_ce_fund_af,
      qt_mat_esp_ce_med,
      qt_mat_esp_ce_prof,
      qt_mat_esp_ce_prof_tec,
      qt_mat_esp_ce_eja,
      qt_mat_esp_ce_eja_fund,
      qt_mat_esp_ce_eja_med,
      qt_mat_bas_fem,
      qt_mat_bas_masc,
      qt_mat_bas_nd,
      qt_mat_bas_branca,
      qt_mat_bas_preta,
      qt_mat_bas_parda,
      qt_mat_bas_amarela,
      qt_mat_bas_indigena,
      qt_mat_bas_0_3,
      qt_mat_bas_4_5,
      qt_mat_bas_6_10,
      qt_mat_bas_11_14,
      qt_mat_bas_15_17,
      qt_mat_bas_18_mais,
      qt_mat_bas_0_3_ref_31_03,
      qt_mat_bas_4_5_ref_31_03,
      qt_mat_bas_6_10_ref_31_03,
      qt_mat_bas_11_14_ref_31_03,
      qt_mat_bas_15_17_ref_31_03,
      qt_mat_bas_18_mais_ref_31_03,
      qt_mat_bas_d,
      qt_mat_bas_dm,
      qt_mat_bas_dv,
      qt_mat_bas_n,
      qt_mat_bas_ead,
      qt_mat_inf_cre_d,
      qt_mat_inf_cre_dm,
      qt_mat_inf_cre_dv,
      qt_mat_inf_cre_n,
      qt_mat_inf_pre_d,
      qt_mat_inf_pre_dm,
      qt_mat_inf_pre_dv,
      qt_mat_inf_pre_n,
      qt_mat_fund_d,
      qt_mat_fund_dm,
      qt_mat_fund_dv,
      qt_mat_fund_n,
      qt_mat_fund_ai_d,
      qt_mat_fund_ai_dm,
      qt_mat_fund_ai_dv,
      qt_mat_fund_ai_n,
      qt_mat_fund_af_d,
      qt_mat_fund_af_dm,
      qt_mat_fund_af_dv,
      qt_mat_fund_af_n,
      qt_mat_med_d,
      qt_mat_med_dm,
      qt_mat_med_dv,
      qt_mat_med_n,
      qt_mat_med_ead,
      qt_mat_prof_d,
      qt_mat_prof_dm,
      qt_mat_prof_dv,
      qt_mat_prof_n,
      qt_mat_prof_ead,
      qt_mat_prof_tec_d,
      qt_mat_prof_tec_dm,
      qt_mat_prof_tec_dv,
      qt_mat_prof_tec_n,
      qt_mat_prof_tec_ead,
      qt_mat_eja_d,
      qt_mat_eja_dm,
      qt_mat_eja_dv,
      qt_mat_eja_n,
      qt_mat_eja_ead,
      qt_mat_eja_fund_d,
      qt_mat_eja_fund_dm,
      qt_mat_eja_fund_dv,
      qt_mat_eja_fund_n,
      qt_mat_eja_fund_ead,
      qt_mat_eja_med_d,
      qt_mat_eja_med_dm,
      qt_mat_eja_med_dv,
      qt_mat_eja_med_n,
      qt_mat_eja_med_ead,
      qt_mat_esp_d,
      qt_mat_esp_dm,
      qt_mat_esp_dv,
      qt_mat_esp_n,
      qt_mat_esp_ead,
      qt_mat_esp_cc_d,
      qt_mat_esp_cc_dm,
      qt_mat_esp_cc_dv,
      qt_mat_esp_cc_n,
      qt_mat_esp_cc_ead,
      qt_mat_esp_ce_d,
      qt_mat_esp_ce_dm,
      qt_mat_esp_ce_dv,
      qt_mat_esp_ce_n,
      qt_mat_esp_ce_ead,
      qt_mat_bas_int,
      qt_mat_inf_int,
      qt_mat_inf_cre_int,
      qt_mat_inf_pre_int,
      qt_mat_fund_int,
      qt_mat_fund_ai_int,
      qt_mat_fund_af_int,
      qt_mat_med_int,
      qt_mat_prof_int,
      qt_mat_prof_tec_int,
      qt_mat_eja_int,
      qt_mat_eja_fund_int,
      qt_mat_eja_med_int,
      qt_mat_esp_int,
      qt_mat_esp_cc_int,
      qt_mat_esp_ce_int,
      qt_mat_bas_libras,
      qt_mat_zr_urb,
      qt_mat_zr_rur,
      qt_mat_zr_na,
      qt_transp_publico,
      qt_transp_resp_est,
      qt_transp_resp_mun
  )
  FROM '/data/Tabela_Matricula_2025.csv'
  DELIMITER ';'
  CSV HEADER;
COMMIT;
