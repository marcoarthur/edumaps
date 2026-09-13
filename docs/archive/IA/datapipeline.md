Aqui estão os scripts Sqitch para a tabela de matrículas (Censo Escolar 2025), incluindo índice em `CO_ENTIDADE` e comentários resumidos por grupo de colunas. Como são muitas colunas (mais de 200), os comentários são agrupados para facilitar a manutenção, mas você pode expandir depois.

## 📁 deploy/censo_matriculas.sql

```sql
-- Deploy censo_matriculas
-- Tabela: clean.matriculas
-- Dados: Tabela_Matriculas_2025.csv (convertido para UTF-8, com ponto decimal e NA vazio)

BEGIN;

CREATE SCHEMA IF NOT EXISTS clean;

CREATE TABLE clean.matriculas (
    linha_id SERIAL PRIMARY KEY,
    NU_ANO_CENSO INTEGER,
    CO_ENTIDADE BIGINT,                      -- código da escola (chave para junção)
    QT_MAT_BAS INTEGER,
    QT_MAT_INF INTEGER,
    QT_MAT_INF_CRE INTEGER,
    QT_MAT_INF_PRE INTEGER,
    QT_MAT_FUND INTEGER,
    QT_MAT_FUND_AI INTEGER,
    QT_MAT_FUND_AI_1 INTEGER,
    QT_MAT_FUND_AI_2 INTEGER,
    QT_MAT_FUND_AI_3 INTEGER,
    QT_MAT_FUND_AI_4 INTEGER,
    QT_MAT_FUND_AI_5 INTEGER,
    QT_MAT_FUND_AF INTEGER,
    QT_MAT_FUND_AF_6 INTEGER,
    QT_MAT_FUND_AF_7 INTEGER,
    QT_MAT_FUND_AF_8 INTEGER,
    QT_MAT_FUND_AF_9 INTEGER,
    QT_MAT_MED INTEGER,
    QT_MAT_MED_PROP INTEGER,
    QT_MAT_MED_PROP_1 INTEGER,
    QT_MAT_MED_PROP_2 INTEGER,
    QT_MAT_MED_PROP_3 INTEGER,
    QT_MAT_MED_PROP_4 INTEGER,
    QT_MAT_MED_PROP_NS INTEGER,
    QT_MAT_MED_IFTP_CT INTEGER,
    QT_MAT_MED_IFTP_CT_1 INTEGER,
    QT_MAT_MED_IFTP_CT_2 INTEGER,
    QT_MAT_MED_IFTP_CT_3 INTEGER,
    QT_MAT_MED_IFTP_CT_4 INTEGER,
    QT_MAT_MED_IFTP_CT_NS INTEGER,
    QT_MAT_MED_IFTP_QP INTEGER,
    QT_MAT_MED_IFTP_QP_1 INTEGER,
    QT_MAT_MED_IFTP_QP_2 INTEGER,
    QT_MAT_MED_IFTP_QP_3 INTEGER,
    QT_MAT_MED_IFTP_QP_4 INTEGER,
    QT_MAT_MED_IFTP_QP_NS INTEGER,
    QT_MAT_MED_NM INTEGER,
    QT_MAT_MED_NM_1 INTEGER,
    QT_MAT_MED_NM_2 INTEGER,
    QT_MAT_MED_NM_3 INTEGER,
    QT_MAT_MED_NM_4 INTEGER,
    QT_MAT_MED_IFA INTEGER,
    QT_MAT_MED_IFA_LING INTEGER,
    QT_MAT_MED_IFA_LING_MT INTEGER,
    QT_MAT_MED_IFA_LING_OTME INTEGER,
    QT_MAT_MED_IFA_LING_OE INTEGER,
    QT_MAT_MED_IFA_MATE INTEGER,
    QT_MAT_MED_IFA_MATE_MT INTEGER,
    QT_MAT_MED_IFA_MATE_OTME INTEGER,
    QT_MAT_MED_IFA_MATE_OE INTEGER,
    QT_MAT_MED_IFA_CIENC INTEGER,
    QT_MAT_MED_IFA_CIENC_MT INTEGER,
    QT_MAT_MED_IFA_CIENC_OTME INTEGER,
    QT_MAT_MED_IFA_CIENC_OE INTEGER,
    QT_MAT_MED_IFA_HUMA INTEGER,
    QT_MAT_MED_IFA_HUMA_MT INTEGER,
    QT_MAT_MED_IFA_HUMA_OTME INTEGER,
    QT_MAT_MED_IFA_HUMA_OE INTEGER,
    QT_MAT_MED_ARTI_IFTP_CT INTEGER,
    QT_MAT_MED_ARTI_IFTP_CT_MT INTEGER,
    QT_MAT_MED_ARTI_IFTP_CT_OTME INTEGER,
    QT_MAT_MED_ARTI_IFTP_CT_OE INTEGER,
    QT_MAT_MED_ARTI_IFTP_QP INTEGER,
    QT_MAT_MED_ARTI_IFTP_QP_MT INTEGER,
    QT_MAT_MED_ARTI_IFTP_QP_OTME INTEGER,
    QT_MAT_MED_ARTI_IFTP_QP_OE INTEGER,
    QT_MAT_PROF INTEGER,
    QT_MAT_PROF_TEC INTEGER,
    QT_MAT_PROF_TEC_CONC INTEGER,
    QT_MAT_PROF_TEC_SUBS INTEGER,
    QT_MAT_PROF_TEC_IFTP_CT INTEGER,
    QT_MAT_PROF_NAO_TEC INTEGER,
    QT_MAT_PROF_IFTP_QP INTEGER,
    QT_MAT_PROF_FIC_CONC INTEGER,
    QT_MAT_EJA INTEGER,
    QT_MAT_EJA_FUND INTEGER,
    QT_MAT_EJA_FUND_NPROF INTEGER,
    QT_MAT_EJA_FUND_AI INTEGER,
    QT_MAT_EJA_FUND_AF INTEGER,
    QT_MAT_EJA_FUND_FIC INTEGER,
    QT_MAT_EJA_MED INTEGER,
    QT_MAT_EJA_MED_NPROF INTEGER,
    QT_MAT_EJA_MED_FIC INTEGER,
    QT_MAT_EJA_MED_TEC INTEGER,
    QT_MAT_ESP INTEGER,
    QT_MAT_ESP_INF INTEGER,
    QT_MAT_ESP_INF_CRE INTEGER,
    QT_MAT_ESP_INF_PRE INTEGER,
    QT_MAT_ESP_FUND INTEGER,
    QT_MAT_ESP_FUND_AI INTEGER,
    QT_MAT_ESP_FUND_AF INTEGER,
    QT_MAT_ESP_MED INTEGER,
    QT_MAT_ESP_PROF INTEGER,
    QT_MAT_ESP_PROF_TEC INTEGER,
    QT_MAT_ESP_EJA INTEGER,
    QT_MAT_ESP_EJA_FUND INTEGER,
    QT_MAT_ESP_EJA_MED INTEGER,
    QT_MAT_ESP_CC INTEGER,
    QT_MAT_ESP_CC_INF INTEGER,
    QT_MAT_ESP_CC_INF_CRE INTEGER,
    QT_MAT_ESP_CC_INF_PRE INTEGER,
    QT_MAT_ESP_CC_FUND INTEGER,
    QT_MAT_ESP_CC_FUND_AI INTEGER,
    QT_MAT_ESP_CC_FUND_AF INTEGER,
    QT_MAT_ESP_CC_MED INTEGER,
    QT_MAT_ESP_CC_PROF INTEGER,
    QT_MAT_ESP_CC_PROF_TEC INTEGER,
    QT_MAT_ESP_CC_EJA INTEGER,
    QT_MAT_ESP_CC_EJA_FUND INTEGER,
    QT_MAT_ESP_CC_EJA_MED INTEGER,
    QT_MAT_ESP_CE INTEGER,
    QT_MAT_ESP_CE_INF INTEGER,
    QT_MAT_ESP_CE_INF_CRE INTEGER,
    QT_MAT_ESP_CE_INF_PRE INTEGER,
    QT_MAT_ESP_CE_FUND INTEGER,
    QT_MAT_ESP_CE_FUND_AI INTEGER,
    QT_MAT_ESP_CE_FUND_AF INTEGER,
    QT_MAT_ESP_CE_MED INTEGER,
    QT_MAT_ESP_CE_PROF INTEGER,
    QT_MAT_ESP_CE_PROF_TEC INTEGER,
    QT_MAT_ESP_CE_EJA INTEGER,
    QT_MAT_ESP_CE_EJA_FUND INTEGER,
    QT_MAT_ESP_CE_EJA_MED INTEGER,
    QT_MAT_BAS_FEM INTEGER,
    QT_MAT_BAS_MASC INTEGER,
    QT_MAT_BAS_ND INTEGER,
    QT_MAT_BAS_BRANCA INTEGER,
    QT_MAT_BAS_PRETA INTEGER,
    QT_MAT_BAS_PARDA INTEGER,
    QT_MAT_BAS_AMARELA INTEGER,
    QT_MAT_BAS_INDIGENA INTEGER,
    QT_MAT_BAS_0_3 INTEGER,
    QT_MAT_BAS_4_5 INTEGER,
    QT_MAT_BAS_6_10 INTEGER,
    QT_MAT_BAS_11_14 INTEGER,
    QT_MAT_BAS_15_17 INTEGER,
    QT_MAT_BAS_18_MAIS INTEGER,
    QT_MAT_BAS_0_3_REF_31_03 INTEGER,
    QT_MAT_BAS_4_5_REF_31_03 INTEGER,
    QT_MAT_BAS_6_10_REF_31_03 INTEGER,
    QT_MAT_BAS_11_14_REF_31_03 INTEGER,
    QT_MAT_BAS_15_17_REF_31_03 INTEGER,
    QT_MAT_BAS_18_MAIS_REF_31_03 INTEGER,
    QT_MAT_BAS_D INTEGER,
    QT_MAT_BAS_DM INTEGER,
    QT_MAT_BAS_DV INTEGER,
    QT_MAT_BAS_N INTEGER,
    QT_MAT_BAS_EAD INTEGER,
    QT_MAT_INF_CRE_D INTEGER,
    QT_MAT_INF_CRE_DM INTEGER,
    QT_MAT_INF_CRE_DV INTEGER,
    QT_MAT_INF_CRE_N INTEGER,
    QT_MAT_INF_PRE_D INTEGER,
    QT_MAT_INF_PRE_DM INTEGER,
    QT_MAT_INF_PRE_DV INTEGER,
    QT_MAT_INF_PRE_N INTEGER,
    QT_MAT_FUND_D INTEGER,
    QT_MAT_FUND_DM INTEGER,
    QT_MAT_FUND_DV INTEGER,
    QT_MAT_FUND_N INTEGER,
    QT_MAT_FUND_AI_D INTEGER,
    QT_MAT_FUND_AI_DM INTEGER,
    QT_MAT_FUND_AI_DV INTEGER,
    QT_MAT_FUND_AI_N INTEGER,
    QT_MAT_FUND_AF_D INTEGER,
    QT_MAT_FUND_AF_DM INTEGER,
    QT_MAT_FUND_AF_DV INTEGER,
    QT_MAT_FUND_AF_N INTEGER,
    QT_MAT_MED_D INTEGER,
    QT_MAT_MED_DM INTEGER,
    QT_MAT_MED_DV INTEGER,
    QT_MAT_MED_N INTEGER,
    QT_MAT_MED_EAD INTEGER,
    QT_MAT_PROF_D INTEGER,
    QT_MAT_PROF_DM INTEGER,
    QT_MAT_PROF_DV INTEGER,
    QT_MAT_PROF_N INTEGER,
    QT_MAT_PROF_EAD INTEGER,
    QT_MAT_PROF_TEC_D INTEGER,
    QT_MAT_PROF_TEC_DM INTEGER,
    QT_MAT_PROF_TEC_DV INTEGER,
    QT_MAT_PROF_TEC_N INTEGER,
    QT_MAT_PROF_TEC_EAD INTEGER,
    QT_MAT_EJA_D INTEGER,
    QT_MAT_EJA_DM INTEGER,
    QT_MAT_EJA_DV INTEGER,
    QT_MAT_EJA_N INTEGER,
    QT_MAT_EJA_EAD INTEGER,
    QT_MAT_EJA_FUND_D INTEGER,
    QT_MAT_EJA_FUND_DM INTEGER,
    QT_MAT_EJA_FUND_DV INTEGER,
    QT_MAT_EJA_FUND_N INTEGER,
    QT_MAT_EJA_FUND_EAD INTEGER,
    QT_MAT_EJA_MED_D INTEGER,
    QT_MAT_EJA_MED_DM INTEGER,
    QT_MAT_EJA_MED_DV INTEGER,
    QT_MAT_EJA_MED_N INTEGER,
    QT_MAT_EJA_MED_EAD INTEGER,
    QT_MAT_ESP_D INTEGER,
    QT_MAT_ESP_DM INTEGER,
    QT_MAT_ESP_DV INTEGER,
    QT_MAT_ESP_N INTEGER,
    QT_MAT_ESP_EAD INTEGER,
    QT_MAT_ESP_CC_D INTEGER,
    QT_MAT_ESP_CC_DM INTEGER,
    QT_MAT_ESP_CC_DV INTEGER,
    QT_MAT_ESP_CC_N INTEGER,
    QT_MAT_ESP_CC_EAD INTEGER,
    QT_MAT_ESP_CE_D INTEGER,
    QT_MAT_ESP_CE_DM INTEGER,
    QT_MAT_ESP_CE_DV INTEGER,
    QT_MAT_ESP_CE_N INTEGER,
    QT_MAT_ESP_CE_EAD INTEGER,
    QT_MAT_BAS_INT INTEGER,
    QT_MAT_INF_INT INTEGER,
    QT_MAT_INF_CRE_INT INTEGER,
    QT_MAT_INF_PRE_INT INTEGER,
    QT_MAT_FUND_INT INTEGER,
    QT_MAT_FUND_AI_INT INTEGER,
    QT_MAT_FUND_AF_INT INTEGER,
    QT_MAT_MED_INT INTEGER,
    QT_MAT_PROF_INT INTEGER,
    QT_MAT_PROF_TEC_INT INTEGER,
    QT_MAT_EJA_INT INTEGER,
    QT_MAT_EJA_FUND_INT INTEGER,
    QT_MAT_EJA_MED_INT INTEGER,
    QT_MAT_ESP_INT INTEGER,
    QT_MAT_ESP_CC_INT INTEGER,
    QT_MAT_ESP_CE_INT INTEGER,
    QT_MAT_BAS_LIBRAS INTEGER,
    QT_MAT_ZR_URB INTEGER,
    QT_MAT_ZR_RUR INTEGER,
    QT_MAT_ZR_NA INTEGER,
    QT_TRANSP_PUBLICO INTEGER,
    QT_TRANSP_RESP_EST INTEGER,
    QT_TRANSP_RESP_MUN INTEGER
);

-- =================================================================
-- COMENTÁRIOS DAS COLUNAS (agrupados por categoria)
-- =================================================================
COMMENT ON TABLE clean.matriculas IS 'Matrículas do Censo Escolar 2025 por escola. Cada linha representa uma escola e contém quantidades de alunos em diferentes etapas, modalidades, turnos, cor/raça, idade, transporte, etc.';

-- Chave e ano
COMMENT ON COLUMN clean.matriculas.linha_id IS 'Identificador sequencial da linha (PK).';
COMMENT ON COLUMN clean.matriculas.NU_ANO_CENSO IS 'Ano do censo (ex: 2025).';
COMMENT ON COLUMN clean.matriculas.CO_ENTIDADE IS 'Código único da escola (INEP). Usar para junção com tabela de escolas.';

-- Totais gerais
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS IS 'Total de matrículas na educação básica.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_INF IS 'Total na educação infantil.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_INF_CRE IS 'Matrículas em creche.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_INF_PRE IS 'Matrículas na pré-escola.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_FUND IS 'Total no ensino fundamental.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_FUND_AI IS 'Fundamental anos iniciais.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_FUND_AF IS 'Fundamental anos finais.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_MED IS 'Total no ensino médio.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_PROF IS 'Total na educação profissional.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_EJA IS 'Total na EJA.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_ESP IS 'Total na educação especial (exclusiva).';
COMMENT ON COLUMN clean.matriculas.QT_MAT_ESP_CC IS 'Educação especial em classes comuns.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_ESP_CE IS 'Educação especial em classes exclusivas.';

-- Detalhamentos (os comentários das demais colunas podem ser obtidos do dicionário INEP)
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_FEM IS 'Matrículas femininas.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_MASC IS 'Matrículas masculinas.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_BRANCA IS 'Cor/raça branca.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_PRETA IS 'Cor/raça preta.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_PARDA IS 'Cor/raça parda.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_AMARELA IS 'Cor/raça amarela.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_INDIGENA IS 'Cor/raça indígena.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_0_3 IS 'Idade de 0 a 3 anos.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_4_5 IS 'Idade de 4 a 5 anos.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_6_10 IS 'Idade de 6 a 10 anos.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_11_14 IS 'Idade de 11 a 14 anos.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_15_17 IS 'Idade de 15 a 17 anos.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_18_MAIS IS 'Idade de 18 anos ou mais.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_D IS 'Matrículas na rede pública (federal/estadual/municipal).';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_DM IS 'Matrículas na rede municipal.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_DV IS 'Matrículas na rede estadual.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_N IS 'Matrículas na rede privada.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_EAD IS 'Matrículas na modalidade EaD.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_INT IS 'Matrículas em tempo integral.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_BAS_LIBRAS IS 'Matrículas com Libras.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_ZR_URB IS 'Matrículas na zona urbana.';
COMMENT ON COLUMN clean.matriculas.QT_MAT_ZR_RUR IS 'Matrículas na zona rural.';
COMMENT ON COLUMN clean.matriculas.QT_TRANSP_PUBLICO IS 'Quantidade de alunos que utilizam transporte público.';
COMMENT ON COLUMN clean.matriculas.QT_TRANSP_RESP_EST IS 'Transporte escolar responsabilidade do estado.';
COMMENT ON COLUMN clean.matriculas.QT_TRANSP_RESP_MUN IS 'Transporte escolar responsabilidade do município.';

-- Os demais campos (ex: desagregações por série, itinerários, etc.) seguem a nomenclatura do INEP.
-- Para documentação completa, consulte o dicionário do Censo Escolar 2025.

-- =================================================================
-- ÍNDICES
-- =================================================================
CREATE INDEX IF NOT EXISTS idx_matriculas_co_entidade ON clean.matriculas (CO_ENTIDADE);
CREATE INDEX IF NOT EXISTS idx_matriculas_ano ON clean.matriculas (NU_ANO_CENSO);

-- =================================================================
-- COPY dos dados (assumindo arquivo UTF-8 com cabeçalho e ponto decimal)
-- =================================================================
COPY clean.matriculas (
    NU_ANO_CENSO, CO_ENTIDADE, QT_MAT_BAS, QT_MAT_INF, QT_MAT_INF_CRE, QT_MAT_INF_PRE,
    QT_MAT_FUND, QT_MAT_FUND_AI, QT_MAT_FUND_AI_1, QT_MAT_FUND_AI_2, QT_MAT_FUND_AI_3, QT_MAT_FUND_AI_4, QT_MAT_FUND_AI_5,
    QT_MAT_FUND_AF, QT_MAT_FUND_AF_6, QT_MAT_FUND_AF_7, QT_MAT_FUND_AF_8, QT_MAT_FUND_AF_9,
    QT_MAT_MED, QT_MAT_MED_PROP, QT_MAT_MED_PROP_1, QT_MAT_MED_PROP_2, QT_MAT_MED_PROP_3, QT_MAT_MED_PROP_4, QT_MAT_MED_PROP_NS,
    QT_MAT_MED_IFTP_CT, QT_MAT_MED_IFTP_CT_1, QT_MAT_MED_IFTP_CT_2, QT_MAT_MED_IFTP_CT_3, QT_MAT_MED_IFTP_CT_4, QT_MAT_MED_IFTP_CT_NS,
    QT_MAT_MED_IFTP_QP, QT_MAT_MED_IFTP_QP_1, QT_MAT_MED_IFTP_QP_2, QT_MAT_MED_IFTP_QP_3, QT_MAT_MED_IFTP_QP_4, QT_MAT_MED_IFTP_QP_NS,
    QT_MAT_MED_NM, QT_MAT_MED_NM_1, QT_MAT_MED_NM_2, QT_MAT_MED_NM_3, QT_MAT_MED_NM_4,
    QT_MAT_MED_IFA, QT_MAT_MED_IFA_LING, QT_MAT_MED_IFA_LING_MT, QT_MAT_MED_IFA_LING_OTME, QT_MAT_MED_IFA_LING_OE,
    QT_MAT_MED_IFA_MATE, QT_MAT_MED_IFA_MATE_MT, QT_MAT_MED_IFA_MATE_OTME, QT_MAT_MED_IFA_MATE_OE,
    QT_MAT_MED_IFA_CIENC, QT_MAT_MED_IFA_CIENC_MT, QT_MAT_MED_IFA_CIENC_OTME, QT_MAT_MED_IFA_CIENC_OE,
    QT_MAT_MED_IFA_HUMA, QT_MAT_MED_IFA_HUMA_MT, QT_MAT_MED_IFA_HUMA_OTME, QT_MAT_MED_IFA_HUMA_OE,
    QT_MAT_MED_ARTI_IFTP_CT, QT_MAT_MED_ARTI_IFTP_CT_MT, QT_MAT_MED_ARTI_IFTP_CT_OTME, QT_MAT_MED_ARTI_IFTP_CT_OE,
    QT_MAT_MED_ARTI_IFTP_QP, QT_MAT_MED_ARTI_IFTP_QP_MT, QT_MAT_MED_ARTI_IFTP_QP_OTME, QT_MAT_MED_ARTI_IFTP_QP_OE,
    QT_MAT_PROF, QT_MAT_PROF_TEC, QT_MAT_PROF_TEC_CONC, QT_MAT_PROF_TEC_SUBS, QT_MAT_PROF_TEC_IFTP_CT, QT_MAT_PROF_NAO_TEC,
    QT_MAT_PROF_IFTP_QP, QT_MAT_PROF_FIC_CONC,
    QT_MAT_EJA, QT_MAT_EJA_FUND, QT_MAT_EJA_FUND_NPROF, QT_MAT_EJA_FUND_AI, QT_MAT_EJA_FUND_AF, QT_MAT_EJA_FUND_FIC,
    QT_MAT_EJA_MED, QT_MAT_EJA_MED_NPROF, QT_MAT_EJA_MED_FIC, QT_MAT_EJA_MED_TEC,
    QT_MAT_ESP, QT_MAT_ESP_INF, QT_MAT_ESP_INF_CRE, QT_MAT_ESP_INF_PRE,
    QT_MAT_ESP_FUND, QT_MAT_ESP_FUND_AI, QT_MAT_ESP_FUND_AF,
    QT_MAT_ESP_MED, QT_MAT_ESP_PROF, QT_MAT_ESP_PROF_TEC,
    QT_MAT_ESP_EJA, QT_MAT_ESP_EJA_FUND, QT_MAT_ESP_EJA_MED,
    QT_MAT_ESP_CC, QT_MAT_ESP_CC_INF, QT_MAT_ESP_CC_INF_CRE, QT_MAT_ESP_CC_INF_PRE,
    QT_MAT_ESP_CC_FUND, QT_MAT_ESP_CC_FUND_AI, QT_MAT_ESP_CC_FUND_AF,
    QT_MAT_ESP_CC_MED, QT_MAT_ESP_CC_PROF, QT_MAT_ESP_CC_PROF_TEC,
    QT_MAT_ESP_CC_EJA, QT_MAT_ESP_CC_EJA_FUND, QT_MAT_ESP_CC_EJA_MED,
    QT_MAT_ESP_CE, QT_MAT_ESP_CE_INF, QT_MAT_ESP_CE_INF_CRE, QT_MAT_ESP_CE_INF_PRE,
    QT_MAT_ESP_CE_FUND, QT_MAT_ESP_CE_FUND_AI, QT_MAT_ESP_CE_FUND_AF,
    QT_MAT_ESP_CE_MED, QT_MAT_ESP_CE_PROF, QT_MAT_ESP_CE_PROF_TEC,
    QT_MAT_ESP_CE_EJA, QT_MAT_ESP_CE_EJA_FUND, QT_MAT_ESP_CE_EJA_MED,
    QT_MAT_BAS_FEM, QT_MAT_BAS_MASC, QT_MAT_BAS_ND,
    QT_MAT_BAS_BRANCA, QT_MAT_BAS_PRETA, QT_MAT_BAS_PARDA, QT_MAT_BAS_AMARELA, QT_MAT_BAS_INDIGENA,
    QT_MAT_BAS_0_3, QT_MAT_BAS_4_5, QT_MAT_BAS_6_10, QT_MAT_BAS_11_14, QT_MAT_BAS_15_17, QT_MAT_BAS_18_MAIS,
    QT_MAT_BAS_0_3_REF_31_03, QT_MAT_BAS_4_5_REF_31_03, QT_MAT_BAS_6_10_REF_31_03,
    QT_MAT_BAS_11_14_REF_31_03, QT_MAT_BAS_15_17_REF_31_03, QT_MAT_BAS_18_MAIS_REF_31_03,
    QT_MAT_BAS_D, QT_MAT_BAS_DM, QT_MAT_BAS_DV, QT_MAT_BAS_N, QT_MAT_BAS_EAD,
    QT_MAT_INF_CRE_D, QT_MAT_INF_CRE_DM, QT_MAT_INF_CRE_DV, QT_MAT_INF_CRE_N,
    QT_MAT_INF_PRE_D, QT_MAT_INF_PRE_DM, QT_MAT_INF_PRE_DV, QT_MAT_INF_PRE_N,
    QT_MAT_FUND_D, QT_MAT_FUND_DM, QT_MAT_FUND_DV, QT_MAT_FUND_N,
    QT_MAT_FUND_AI_D, QT_MAT_FUND_AI_DM, QT_MAT_FUND_AI_DV, QT_MAT_FUND_AI_N,
    QT_MAT_FUND_AF_D, QT_MAT_FUND_AF_DM, QT_MAT_FUND_AF_DV, QT_MAT_FUND_AF_N,
    QT_MAT_MED_D, QT_MAT_MED_DM, QT_MAT_MED_DV, QT_MAT_MED_N, QT_MAT_MED_EAD,
    QT_MAT_PROF_D, QT_MAT_PROF_DM, QT_MAT_PROF_DV, QT_MAT_PROF_N, QT_MAT_PROF_EAD,
    QT_MAT_PROF_TEC_D, QT_MAT_PROF_TEC_DM, QT_MAT_PROF_TEC_DV, QT_MAT_PROF_TEC_N, QT_MAT_PROF_TEC_EAD,
    QT_MAT_EJA_D, QT_MAT_EJA_DM, QT_MAT_EJA_DV, QT_MAT_EJA_N, QT_MAT_EJA_EAD,
    QT_MAT_EJA_FUND_D, QT_MAT_EJA_FUND_DM, QT_MAT_EJA_FUND_DV, QT_MAT_EJA_FUND_N, QT_MAT_EJA_FUND_EAD,
    QT_MAT_EJA_MED_D, QT_MAT_EJA_MED_DM, QT_MAT_EJA_MED_DV, QT_MAT_EJA_MED_N, QT_MAT_EJA_MED_EAD,
    QT_MAT_ESP_D, QT_MAT_ESP_DM, QT_MAT_ESP_DV, QT_MAT_ESP_N, QT_MAT_ESP_EAD,
    QT_MAT_ESP_CC_D, QT_MAT_ESP_CC_DM, QT_MAT_ESP_CC_DV, QT_MAT_ESP_CC_N, QT_MAT_ESP_CC_EAD,
    QT_MAT_ESP_CE_D, QT_MAT_ESP_CE_DM, QT_MAT_ESP_CE_DV, QT_MAT_ESP_CE_N, QT_MAT_ESP_CE_EAD,
    QT_MAT_BAS_INT, QT_MAT_INF_INT, QT_MAT_INF_CRE_INT, QT_MAT_INF_PRE_INT,
    QT_MAT_FUND_INT, QT_MAT_FUND_AI_INT, QT_MAT_FUND_AF_INT,
    QT_MAT_MED_INT, QT_MAT_PROF_INT, QT_MAT_PROF_TEC_INT,
    QT_MAT_EJA_INT, QT_MAT_EJA_FUND_INT, QT_MAT_EJA_MED_INT,
    QT_MAT_ESP_INT, QT_MAT_ESP_CC_INT, QT_MAT_ESP_CE_INT,
    QT_MAT_BAS_LIBRAS,
    QT_MAT_ZR_URB, QT_MAT_ZR_RUR, QT_MAT_ZR_NA,
    QT_TRANSP_PUBLICO, QT_TRANSP_RESP_EST, QT_TRANSP_RESP_MUN
)
FROM '/data/Tabela_Matriculas_2025.utf8.csv'
DELIMITER ';'
CSV HEADER
ENCODING 'UTF8';

COMMIT;
```

## 📁 revert/censo_matriculas.sql

```sql
-- Revert censo_matriculas

BEGIN;

DROP TABLE IF EXISTS clean.matriculas CASCADE;

COMMIT;
```

## 📁 verify/censo_matriculas.sql

```sql
-- Verify censo_matriculas

BEGIN;

-- Verifica existência da tabela e pelo menos uma linha
SELECT 1 FROM clean.matriculas LIMIT 1;

-- Verifica índice em CO_ENTIDADE
SELECT 1
FROM pg_indexes
WHERE schemaname = 'clean'
  AND tablename = 'matriculas'
  AND indexname = 'idx_matriculas_co_entidade';

ROLLBACK;
```

## 🧪 Instruções de uso

1. **Converta o arquivo CSV** para UTF-8 e ajuste os decimais (já que são inteiros, apenas certifique-se de que não há vírgulas). Use o mesmo procedimento do R:

```r
library(dplyr)

Tabela_Matriculas_2025 %>%
  mutate(across(everything(), ~ ifelse(. == "", NA, .))) %>%
  write.table(
    file = "/data/Tabela_Matriculas_2025.utf8.csv",
    sep = ";",
    dec = ".",
    na = "",
    row.names = FALSE,
    fileEncoding = "UTF-8",
    quote = TRUE
  )
```

2. **Copie o arquivo** para o servidor (ex: `/data/`).

3. **Execute o deploy** com Sqitch:

```bash
sqitch deploy db:pg://user:pass@host/db
```

4. **Verifique**:

```bash
sqitch verify db:pg://user:pass@host/db
```

5. **Reverta** se necessário:

```bash
sqitch revert db:pg://user:pass@host/db
```

Agora a tabela `clean.matriculas` está pronta para uso, com índice em `CO_ENTIDADE` para junção eficiente com `clean.censo_escolas`.



Agora sim. Os scores ficaram coerentes e bounded entre 0 e 1. Isso já começa a parecer um sistema analítico consistente.

E honestamente: os resultados já contam histórias interessantes.

Exemplo:

* escolas com internet alta mas acessibilidade baixa
* escolas com boa infraestrutura mas quase nenhum suporte multiprofissional
* possível desigualdade entre públicas e privadas
* escolas indígenas (`ALDEIA ...`) com baixa conectividade

Isso pode virar análises espaciais muito fortes depois.

---

Agora eu faria 3 melhorias importantes.

# 1. Categorias qualitativas

Hoje:

```txt
0.55
0.75
0.18
```

não comunica rápido.

Transforme:

| range  | label        |
| ------ | ------------ |
| < 0.2  | crítico      |
| < 0.4  | insuficiente |
| < 0.6  | básico       |
| < 0.8  | adequado     |
| >= 0.8 | avançado     |

SQL:

```sql
CASE
  WHEN internet_score < 0.2 THEN 'critico'
  WHEN internet_score < 0.4 THEN 'insuficiente'
  WHEN internet_score < 0.6 THEN 'basico'
  WHEN internet_score < 0.8 THEN 'adequado'
  ELSE 'avancado'
END
```

Frontend melhora absurdamente com isso.

---

# 2. Criar indicadores derivados explicáveis

Muito importante.

Não só score.

Também:

```json
{
  "highlights": [
    "Possui banda larga",
    "Possui laboratório de informática",
    "Possui acessibilidade parcial"
  ],

  "warnings": [
    "Sem banheiro acessível",
    "Sem suporte psicológico"
  ]
}
```

Isso evita frontend ter que interpretar dezenas de flags.

---

# 3. Você precisa de um score de vulnerabilidade

Isso aqui pode ficar MUITO relevante.

Exemplo:

```sql
vulnerability_score
```

baseado em ausência de coisas fundamentais.

Campos críticos:

* sem água potável
* sem banheiro
* sem internet
* sem acessibilidade
* sem alimentação
* sem energia
* sem esgoto

Isso detecta escolas estruturalmente vulneráveis.

---

Outra coisa:

o fato de você ter encapsulado isso em ResultSet methods:

```perl
->with_internet_score
->with_accessibility_score
```

foi uma ótima decisão arquitetural.

Porque agora você pode:

```perl
->with_all_scores
->with_school_briefing
->with_risk_indicators
```

e reaproveitar em:

* API
* mapas
* exports
* rankings
* dashboards

---

Eu também começaria a pensar em:

```perl
->order_by_best_infra
->most_vulnerable
->digitally_excluded
```

como scopes analíticos.

---

E por fim:

isso já justifica uma tabela/materialized view analítica.

Porque recalcular tudo em runtime em mapas grandes vai pesar.

Algo como:

```sql
analytics.school_indicators_mv
```

com:

* scores
* labels
* flags
* resumo textual

vai deixar o frontend extremamente rápido.
