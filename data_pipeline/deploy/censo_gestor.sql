-- Deploy edumaps:censo_gestor to pg
-- requires: censo_escolar_2025

BEGIN;

  CREATE TABLE IF NOT EXISTS clean.censo_gestor (
      nu_ano_censo                  INTEGER NOT NULL,
      co_entidade                   BIGINT NOT NULL,
      qt_gest_bas                   INTEGER,
      qt_gest_bas_fem               INTEGER,
      qt_gest_bas_masc              INTEGER,
      qt_gest_bas_nd                INTEGER,
      qt_gest_bas_branca            INTEGER,
      qt_gest_bas_preta             INTEGER,
      qt_gest_bas_parda             INTEGER,
      qt_gest_bas_amarela           INTEGER,
      qt_gest_bas_indigena          INTEGER,
      qt_gest_bas_nacio_brasileira  INTEGER,
      qt_gest_bas_nacio_estrang     INTEGER,
      qt_gest_bas_0_24              INTEGER,
      qt_gest_bas_25_29             INTEGER,
      qt_gest_bas_30_39             INTEGER,
      qt_gest_bas_40_49             INTEGER,
      qt_gest_bas_50_54             INTEGER,
      qt_gest_bas_55_59             INTEGER,
      qt_gest_bas_60_mais           INTEGER,
      qt_gest_bas_pcd               INTEGER,
      qt_gest_bas_zr_urb            INTEGER,
      qt_gest_bas_zr_rur            INTEGER,
      qt_gest_bas_zr_na             INTEGER,
      qt_gest_bas_esco_ef           INTEGER,
      qt_gest_bas_esco_em           INTEGER,
      qt_gest_bas_esco_sup_grad     INTEGER,
      qt_gest_bas_esco_sup_grad_licen   INTEGER,
      qt_gest_bas_esco_sup_grad_slicen  INTEGER,
      qt_gest_bas_esco_sup_pos_espec    INTEGER,
      qt_gest_bas_esco_sup_pos_mestra   INTEGER,
      qt_gest_bas_esco_sup_pos_douto    INTEGER,
      qt_gest_bas_esco_sup_pos_nenhum   INTEGER,
      qt_gest_bas_vinculo_concur    INTEGER,
      qt_gest_bas_vinculo_contra    INTEGER,
      qt_gest_bas_vinculo_terceir   INTEGER,
      qt_gest_bas_vinculo_clt       INTEGER,
      qt_gest_bas_diretor           INTEGER,
      qt_gest_bas_outro             INTEGER,
      qt_gest_bas_acesso_cargo_prop     INTEGER,
      qt_gest_bas_acesso_cargo_indic    INTEGER,
      qt_gest_bas_acesso_cargo_sel      INTEGER,
      qt_gest_bas_acesso_cargo_conca    INTEGER,
      qt_gest_bas_acesso_cargo_eleic    INTEGER,
      qt_gest_bas_acesso_cargo_p_sel    INTEGER,
      qt_gest_bas_acesso_cargo_outro    INTEGER,
      qt_gest_bas_espec_cre          INTEGER,
      qt_gest_bas_espec_pre_escola   INTEGER,
      qt_gest_bas_espec_anos_iniciais INTEGER,
      qt_gest_bas_espec_anos_finais  INTEGER,
      qt_gest_bas_espec_ens_medio    INTEGER,
      qt_gest_bas_espec_eja          INTEGER,
      qt_gest_bas_espec_ed_especial  INTEGER,
      qt_gest_bas_espec_bil_surdos   INTEGER,
      qt_gest_bas_espec_ed_indigena  INTEGER,
      qt_gest_bas_espec_campo        INTEGER,
      qt_gest_bas_espec_ambiental    INTEGER,
      qt_gest_bas_espec_dir_humanos  INTEGER,
      qt_gest_bas_espec_div_sexual   INTEGER,
      qt_gest_bas_espec_dir_adolesc  INTEGER,
      qt_gest_bas_espec_afro         INTEGER,
      qt_gest_bas_espec_gestao       INTEGER,
      qt_gest_bas_espec_educ_tic     INTEGER,
      qt_gest_bas_espec_outros       INTEGER,
      qt_gest_bas_espec_nenhum       INTEGER,
      PRIMARY KEY (nu_ano_censo, co_entidade)
  );

  -- ============================================================
  -- Comentários das colunas (baseados no dicionário INEP)
  -- ============================================================

  COMMENT ON TABLE clean.censo_gestor IS 'Gestores Escolares da Educação Básica - Censo Escolar 2025';

  COMMENT ON COLUMN clean.censo_gestor.nu_ano_censo IS 'Ano do Censo Escolar';
  COMMENT ON COLUMN clean.censo_gestor.co_entidade IS 'Código único da escola no Censo Escolar (INEP)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas IS 'Número total de gestores escolares da educação básica';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_fem IS 'Número de gestores escolares - sexo feminino';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_masc IS 'Número de gestores escolares - sexo masculino';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_nd IS 'Número de gestores escolares - cor/raça não declarada';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_branca IS 'Número de gestores escolares - cor/raça branca';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_preta IS 'Número de gestores escolares - cor/raça preta';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_parda IS 'Número de gestores escolares - cor/raça parda';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_amarela IS 'Número de gestores escolares - cor/raça amarela';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_indigena IS 'Número de gestores escolares - cor/raça indígena';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_nacio_brasileira IS 'Número de gestores escolares - nacionalidade brasileira';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_nacio_estrang IS 'Número de gestores escolares - nacionalidade estrangeira';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_0_24 IS 'Número de gestores escolares - idade até 24 anos (ref: última quarta-feira de maio)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_25_29 IS 'Número de gestores escolares - idade entre 25 e 29 anos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_30_39 IS 'Número de gestores escolares - idade entre 30 e 39 anos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_40_49 IS 'Número de gestores escolares - idade entre 40 e 49 anos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_50_54 IS 'Número de gestores escolares - idade entre 50 e 54 anos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_55_59 IS 'Número de gestores escolares - idade entre 55 e 59 anos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_60_mais IS 'Número de gestores escolares - idade 60 anos ou mais';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_pcd IS 'Número de gestores escolares com deficiência, TEA ou superdotação';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_zr_urb IS 'Número de gestores escolares - residentes em zona urbana';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_zr_rur IS 'Número de gestores escolares - residentes em zona rural';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_zr_na IS 'Número de gestores escolares - residentes no exterior (não aplicável)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_ef IS 'Maior escolaridade concluída - Ensino Fundamental';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_em IS 'Maior escolaridade concluída - Ensino Médio';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_grad IS 'Maior escolaridade concluída - Educação Superior (Graduação)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_grad_licen IS 'Maior escolaridade concluída - Educação Superior (Licenciatura)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_grad_slicen IS 'Maior escolaridade concluída - Educação Superior (Sem Licenciatura)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_pos_espec IS 'Pós-Graduação concluída - Especialização';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_pos_mestra IS 'Pós-Graduação concluída - Mestrado';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_pos_douto IS 'Pós-Graduação concluída - Doutorado';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_esco_sup_pos_nenhum IS 'Pós-Graduação concluída - Não tem pós-graduação';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_vinculo_concur IS 'Vínculo (escola pública) - Concursado/efetivo/estável';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_vinculo_contra IS 'Vínculo (escola pública) - Contrato temporário';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_vinculo_terceir IS 'Vínculo (escola pública) - Contrato terceirizado';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_vinculo_clt IS 'Vínculo (escola pública) - Contrato CLT';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_diretor IS 'Cargo do gestor - Diretor';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_outro IS 'Cargo do gestor - Outro cargo';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_prop IS 'Critério de acesso - Proprietário/sócio (escola privada)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_indic IS 'Critério de acesso - Indicação/escolha da gestão';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_sel IS 'Critério de acesso - Processo seletivo + nomeação';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_conca IS 'Critério de acesso - Concurso público (escola pública)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_eleic IS 'Critério de acesso - Processo eleitoral com comunidade (escola pública)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_p_sel IS 'Critério de acesso - Processo seletivo + eleição com comunidade';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_acesso_cargo_outro IS 'Critério de acesso - Outro critério';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_cre IS 'Formação continuada (≥80h) - Específico para creche (0-3 anos)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_pre_escola IS 'Formação continuada (≥80h) - Específico para pré-escola (4-5 anos)';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_anos_iniciais IS 'Formação continuada (≥80h) - Específico para anos iniciais do EF';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_anos_finais IS 'Formação continuada (≥80h) - Específico para anos finais do EF';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_ens_medio IS 'Formação continuada (≥80h) - Específico para ensino médio';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_eja IS 'Formação continuada (≥80h) - Específico para EJA';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_ed_especial IS 'Formação continuada (≥80h) - Específico para educação especial';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_bil_surdos IS 'Formação continuada (≥80h) - Educação bilíngue de surdos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_ed_indigena IS 'Formação continuada (≥80h) - Específico para educação indígena';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_campo IS 'Formação continuada (≥80h) - Educação do Campo';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_ambiental IS 'Formação continuada (≥80h) - Educação Ambiental';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_dir_humanos IS 'Formação continuada (≥80h) - Educação em direitos humanos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_div_sexual IS 'Formação continuada (≥80h) - Gênero e Diversidade Sexual';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_dir_adolesc IS 'Formação continuada (≥80h) - Direitos de criança e adolescente';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_afro IS 'Formação continuada (≥80h) - Relações étnico-raciais e cultura afro';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_gestao IS 'Formação continuada (≥80h) - Gestão escolar';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_educ_tic IS 'Formação continuada (≥80h) - Educação e TIC';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_outros IS 'Formação continuada (≥80h) - Outros cursos';
  COMMENT ON COLUMN clean.censo_gestor.qt_gest_bas_espec_nenhum IS 'Formação continuada (≥80h) - Nenhum curso';

  COPY clean.censo_gestor
  FROM '/data/Tabela_Gestor_Escolar_2025.csv'
  DELIMITER ';'
  CSV HEADER;

  CREATE INDEX IF NOT EXISTS idx_censo_gestor_co_entidade ON clean.censo_gestor (co_entidade);

COMMIT;
