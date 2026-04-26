-- Deploy edumaps:censo_escolar_2025 to pg

BEGIN;

  SET datestyle = 'ISO, DMY'; -- para interpretar DD/MM/AAAA

  CREATE TABLE clean.censo_escolas (
      linha_id SERIAL PRIMARY KEY, -- número da linha (1 = primeira linha de dados)
      NU_ANO_CENSO INTEGER,
      NO_REGIAO VARCHAR(20),
      CO_REGIAO SMALLINT,
      NO_UF VARCHAR(50),
      SG_UF CHAR(2),
      CO_UF SMALLINT,
      NO_MUNICIPIO VARCHAR(100),
      CO_MUNICIPIO INTEGER,
      NO_REGIAO_GEOG_INTERM VARCHAR(100),
      CO_REGIAO_GEOG_INTERM INTEGER,
      NO_REGIAO_GEOG_IMED VARCHAR(100),
      CO_REGIAO_GEOG_IMED INTEGER,
      NO_MESORREGIAO VARCHAR(100),
      CO_MESORREGIAO INTEGER,
      NO_MICRORREGIAO VARCHAR(100),
      CO_MICRORREGIAO INTEGER,
      NO_DISTRITO VARCHAR(100),
      CO_DISTRITO INTEGER,
      NO_REGIAO_ADMINISTRATIVA VARCHAR(100),
      CO_REGIAO_ADMINISTRATIVA INTEGER,
      NO_ENTIDADE VARCHAR(255),
      CO_ENTIDADE BIGINT NOT NULL, -- identificador único da escola
      TP_DEPENDENCIA SMALLINT,
      TP_CATEGORIA_ESCOLA_PRIVADA SMALLINT,
      TP_LOCALIZACAO SMALLINT,
      TP_LOCALIZACAO_DIFERENCIADA SMALLINT,
      DS_ENDERECO VARCHAR(255),
      NU_ENDERECO VARCHAR(20),
      DS_COMPLEMENTO VARCHAR(100),
      NO_BAIRRO VARCHAR(100),
      CO_CEP VARCHAR(10),
      NU_DDD SMALLINT,
      NU_TELEFONE VARCHAR(20),
      LATITUDE NUMERIC(10,8),
      LONGITUDE NUMERIC(11,8),
      TP_SITUACAO_FUNCIONAMENTO SMALLINT,
      CO_ORGAO_REGIONAL VARCHAR(20),
      DT_ANO_LETIVO_INICIO DATE,
      DT_ANO_LETIVO_TERMINO DATE,
      IN_VINCULO_SECRETARIA_EDUCACAO SMALLINT,
      IN_VINCULO_SEGURANCA_PUBLICA SMALLINT,
      IN_VINCULO_SECRETARIA_SAUDE SMALLINT,
      IN_VINCULO_OUTRO_ORGAO SMALLINT,
      IN_PODER_PUBLICO_PARCERIA SMALLINT,
      TP_PODER_PUBLICO_PARCERIA SMALLINT,
      IN_FORMA_CONT_TERMO_COLABORA SMALLINT,
      IN_FORMA_CONT_TERMO_FOMENTO SMALLINT,
      IN_FORMA_CONT_ACORDO_COOP SMALLINT,
      IN_FORMA_CONT_PRESTACAO_SERV SMALLINT,
      IN_FORMA_CONT_COOP_TEC_FIN SMALLINT,
      IN_FORMA_CONT_CONSORCIO_PUB SMALLINT,
      IN_FORMA_CONT_MU_TERMO_COLAB SMALLINT,
      IN_FORMA_CONT_MU_TERMO_FOMENTO SMALLINT,
      IN_FORMA_CONT_MU_ACORDO_COOP SMALLINT,
      IN_FORMA_CONT_MU_PREST_SERV SMALLINT,
      IN_FORMA_CONT_MU_COOP_TEC_FIN SMALLINT,
      IN_FORMA_CONT_MU_CONSORCIO_PUB SMALLINT,
      IN_FORMA_CONT_ES_TERMO_COLAB SMALLINT,
      IN_FORMA_CONT_ES_TERMO_FOMENTO SMALLINT,
      IN_FORMA_CONT_ES_ACORDO_COOP SMALLINT,
      IN_FORMA_CONT_ES_PREST_SERV SMALLINT,
      IN_FORMA_CONT_ES_COOP_TEC_FIN SMALLINT,
      IN_FORMA_CONT_ES_CONSORCIO_PUB SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_EMP SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_ONG SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_OSCIP SMALLINT,
      IN_MANT_ESCOLA_PRIV_ONG_OSCIP SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_SIND SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_SIST_S SMALLINT,
      IN_MANT_ESCOLA_PRIVADA_S_FINS SMALLINT,
      NU_CNPJ_ESCOLA_PRIVADA VARCHAR(18),
      NU_CNPJ_MANTENEDORA VARCHAR(18),
      TP_REGULAMENTACAO SMALLINT,
      TP_RESPONSAVEL_REGULAMENTACAO SMALLINT,
      CO_ESCOLA_SEDE_VINCULADA BIGINT,
      CO_IES_OFERTANTE INTEGER,
      IN_LOCAL_FUNC_PREDIO_ESCOLAR SMALLINT,
      TP_OCUPACAO_PREDIO_ESCOLAR SMALLINT,
      IN_LOCAL_FUNC_SOCIOEDUCATIVO SMALLINT,
      IN_LOCAL_FUNC_UNID_PRISIONAL SMALLINT,
      IN_LOCAL_FUNC_PRISIONAL_SOCIO SMALLINT,
      IN_LOCAL_FUNC_GALPAO SMALLINT,
      TP_OCUPACAO_GALPAO SMALLINT,
      IN_LOCAL_FUNC_SALAS_OUTRA_ESC SMALLINT,
      IN_LOCAL_FUNC_OUTROS SMALLINT,
      IN_PREDIO_COMPARTILHADO SMALLINT,
      IN_AGUA_POTAVEL SMALLINT,
      IN_AGUA_REDE_PUBLICA SMALLINT,
      IN_AGUA_POCO_ARTESIANO SMALLINT,
      IN_AGUA_CACIMBA SMALLINT,
      IN_AGUA_FONTE_RIO SMALLINT,
      IN_AGUA_INEXISTENTE SMALLINT,
      IN_AGUA_CARRO_PIPA SMALLINT,
      IN_ENERGIA_REDE_PUBLICA SMALLINT,
      IN_ENERGIA_GERADOR_FOSSIL SMALLINT,
      IN_ENERGIA_RENOVAVEL SMALLINT,
      IN_ENERGIA_INEXISTENTE SMALLINT,
      IN_ESGOTO_REDE_PUBLICA SMALLINT,
      IN_ESGOTO_FOSSA_SEPTICA SMALLINT,
      IN_ESGOTO_FOSSA_COMUM SMALLINT,
      IN_ESGOTO_FOSSA SMALLINT,
      IN_ESGOTO_INEXISTENTE SMALLINT,
      IN_LIXO_SERVICO_COLETA SMALLINT,
      IN_LIXO_QUEIMA SMALLINT,
      IN_LIXO_ENTERRA SMALLINT,
      IN_LIXO_DESTINO_FINAL_PUBLICO SMALLINT,
      IN_LIXO_DESCARTA_OUTRA_AREA SMALLINT,
      IN_TRATAMENTO_LIXO_SEPARACAO SMALLINT,
      IN_TRATAMENTO_LIXO_REUTILIZA SMALLINT,
      IN_TRATAMENTO_LIXO_RECICLAGEM SMALLINT,
      IN_TRATAMENTO_LIXO_INEXISTENTE SMALLINT,
      IN_ALMOXARIFADO SMALLINT,
      IN_AREA_VERDE SMALLINT,
      IN_AREA_PLANTIO SMALLINT,
      IN_AUDITORIO SMALLINT,
      IN_BANHEIRO SMALLINT,
      IN_BANHEIRO_EI SMALLINT,
      IN_BANHEIRO_PNE SMALLINT,
      IN_BANHEIRO_FUNCIONARIOS SMALLINT,
      IN_BANHEIRO_CHUVEIRO SMALLINT,
      IN_BIBLIOTECA SMALLINT,
      IN_BIBLIOTECA_SALA_LEITURA SMALLINT,
      IN_COZINHA SMALLINT,
      IN_DESPENSA SMALLINT,
      IN_DORMITORIO_ALUNO SMALLINT,
      IN_DORMITORIO_PROFESSOR SMALLINT,
      IN_LABORATORIO_CIENCIAS SMALLINT,
      IN_LABORATORIO_INFORMATICA SMALLINT,
      IN_LABORATORIO_EDUC_PROF SMALLINT,
      IN_PATIO_COBERTO SMALLINT,
      IN_PATIO_DESCOBERTO SMALLINT,
      IN_PARQUE_INFANTIL SMALLINT,
      IN_PISCINA SMALLINT,
      IN_QUADRA_ESPORTES SMALLINT,
      IN_QUADRA_ESPORTES_COBERTA SMALLINT,
      IN_QUADRA_ESPORTES_DESCOBERTA SMALLINT,
      IN_REFEITORIO SMALLINT,
      IN_SALA_ATELIE_ARTES SMALLINT,
      IN_SALA_MUSICA_CORAL SMALLINT,
      IN_SALA_ESTUDIO_DANCA SMALLINT,
      IN_SALA_MULTIUSO SMALLINT,
      IN_SALA_ESTUDIO_GRAVACAO SMALLINT,
      IN_SALA_OFICINAS_EDUC_PROF SMALLINT,
      IN_SALA_DIRETORIA SMALLINT,
      IN_SALA_LEITURA SMALLINT,
      IN_SALA_PROFESSOR SMALLINT,
      IN_SALA_REPOUSO_ALUNO SMALLINT,
      IN_SECRETARIA SMALLINT,
      IN_SALA_ATENDIMENTO_ESPECIAL SMALLINT,
      IN_TERREIRAO SMALLINT,
      IN_VIVEIRO SMALLINT,
      IN_DEPENDENCIAS_OUTRAS SMALLINT,
      IN_ACESSIBILIDADE_CORRIMAO SMALLINT,
      IN_ACESSIBILIDADE_ELEVADOR SMALLINT,
      IN_ACESSIBILIDADE_PISOS_TATEIS SMALLINT,
      IN_ACESSIBILIDADE_VAO_LIVRE SMALLINT,
      IN_ACESSIBILIDADE_RAMPAS SMALLINT,
      IN_ACESSIBILIDADE_SINAL_SONORO SMALLINT,
      IN_ACESSIBILIDADE_SINAL_TATIL SMALLINT,
      IN_ACESSIBILIDADE_SINAL_VISUAL SMALLINT,
      IN_ACESSIBILIDADE_INEXISTENTE SMALLINT,
      IN_ACESSIBILIDADE_SINALIZACAO SMALLINT,
      QT_SALAS_UTILIZADAS_DENTRO INTEGER,
      QT_SALAS_UTILIZADAS_FORA INTEGER,
      QT_SALAS_UTILIZADAS INTEGER,
      QT_SALAS_UTILIZA_CLIMATIZADAS INTEGER,
      QT_SALAS_UTILIZADAS_ACESSIVEIS INTEGER,
      QT_SALAS_LEITURA INTEGER,
      IN_EQUIP_PARABOLICA SMALLINT,
      IN_COMPUTADOR SMALLINT,
      IN_EQUIP_COPIADORA SMALLINT,
      IN_EQUIP_IMPRESSORA SMALLINT,
      IN_EQUIP_IMPRESSORA_MULT SMALLINT,
      IN_EQUIP_SCANNER SMALLINT,
      IN_EQUIP_NENHUM SMALLINT,
      IN_EQUIP_DVD SMALLINT,
      QT_EQUIP_DVD INTEGER,
      IN_EQUIP_SOM SMALLINT,
      QT_EQUIP_SOM INTEGER,
      IN_EQUIP_TV SMALLINT,
      QT_EQUIP_TV INTEGER,
      IN_EQUIP_LOUSA_DIGITAL SMALLINT,
      QT_EQUIP_LOUSA_DIGITAL INTEGER,
      IN_EQUIP_MULTIMIDIA SMALLINT,
      QT_EQUIP_MULTIMIDIA INTEGER,
      IN_DESKTOP_ALUNO SMALLINT,
      QT_DESKTOP_ALUNO INTEGER,
      IN_COMP_PORTATIL_ALUNO SMALLINT,
      QT_COMP_PORTATIL_ALUNO INTEGER,
      IN_TABLET_ALUNO SMALLINT,
      QT_TABLET_ALUNO INTEGER,
      IN_INTERNET SMALLINT,
      IN_INTERNET_ALUNOS SMALLINT,
      IN_INTERNET_ADMINISTRATIVO SMALLINT,
      IN_INTERNET_APRENDIZAGEM SMALLINT,
      IN_INTERNET_COMUNIDADE SMALLINT,
      IN_ACESSO_INTERNET_COMPUTADOR SMALLINT,
      IN_ACES_INTERNET_DISP_PESSOAIS SMALLINT,
      TP_REDE_LOCAL SMALLINT,
      IN_BANDA_LARGA SMALLINT,
      QT_PROF_ADMINISTRATIVOS INTEGER,
      QT_PROF_SERVICOS_GERAIS INTEGER,
      QT_PROF_BIBLIOTECARIO INTEGER,
      QT_PROF_SAUDE INTEGER,
      QT_PROF_COORDENADOR INTEGER,
      QT_PROF_FONAUDIOLOGO INTEGER,
      QT_PROF_NUTRICIONISTA INTEGER,
      QT_PROF_PSICOLOGO INTEGER,
      QT_PROF_ALIMENTACAO INTEGER,
      QT_PROF_PEDAGOGIA INTEGER,
      QT_PROF_SECRETARIO INTEGER,
      QT_PROF_SEGURANCA INTEGER,
      QT_PROF_MONITORES INTEGER,
      QT_PROF_GESTAO INTEGER,
      QT_PROF_ASSIST_SOCIAL INTEGER,
      QT_PROF_TRAD_LIBRAS INTEGER,
      QT_PROF_AGRICOLA INTEGER,
      QT_PROF_REVISOR_BRAILLE INTEGER,
      IN_ALIMENTACAO SMALLINT,
      IN_MATERIAL_PED_MULTIMIDIA SMALLINT,
      IN_MATERIAL_PED_INFANTIL SMALLINT,
      IN_MATERIAL_PED_CIENTIFICO SMALLINT,
      IN_MATERIAL_PED_DIFUSAO SMALLINT,
      IN_MATERIAL_PED_MUSICAL SMALLINT,
      IN_MATERIAL_PED_JOGOS SMALLINT,
      IN_MATERIAL_PED_ARTISTICAS SMALLINT,
      IN_MATERIAL_PED_PROFISSIONAL SMALLINT,
      IN_MATERIAL_PED_DESPORTIVA SMALLINT,
      IN_MATERIAL_PED_INDIGENA SMALLINT,
      IN_MATERIAL_PED_ETNICO SMALLINT,
      IN_MATERIAL_PED_CAMPO SMALLINT,
      IN_MATERIAL_PED_BIL_SURDOS SMALLINT,
      IN_MATERIAL_PED_AGRICOLA SMALLINT,
      IN_MATERIAL_PED_QUILOMBOLA SMALLINT,
      IN_MATERIAL_PED_EDU_ESP SMALLINT,
      IN_MATERIAL_PED_NENHUM SMALLINT,
      IN_EDUCACAO_INDIGENA SMALLINT,
      TP_INDIGENA_LINGUA SMALLINT,
      CO_LINGUA_INDIGENA_1 INTEGER,
      CO_LINGUA_INDIGENA_2 INTEGER,
      CO_LINGUA_INDIGENA_3 INTEGER,
      IN_EXAME_SELECAO SMALLINT,
      IN_RESERVA_PPI SMALLINT,
      IN_RESERVA_RENDA SMALLINT,
      IN_RESERVA_PUBLICA SMALLINT,
      IN_RESERVA_PCD SMALLINT,
      IN_RESERVA_OUTROS SMALLINT,
      IN_RESERVA_NENHUMA SMALLINT,
      IN_REDES_SOCIAIS SMALLINT,
      IN_ESPACO_ATIVIDADE SMALLINT,
      IN_ESPACO_EQUIPAMENTO SMALLINT,
      IN_ORGAO_ASS_PAIS SMALLINT,
      IN_ORGAO_ASS_PAIS_MESTRES SMALLINT,
      IN_ORGAO_CONSELHO_ESCOLAR SMALLINT,
      IN_ORGAO_GREMIO_ESTUDANTIL SMALLINT,
      IN_ORGAO_OUTROS SMALLINT,
      IN_ORGAO_NENHUM SMALLINT,
      TP_PROPOSTA_PEDAGOGICA SMALLINT,
      IN_EDUC_AMBIENTAL SMALLINT,
      IN_EDUC_AMB_CONTEUDO SMALLINT,
      IN_EDUC_AMB_CURRICULAR SMALLINT,
      IN_EDUC_AMB_EIXO SMALLINT,
      IN_EDUC_AMB_EVENTOS SMALLINT,
      IN_EDUC_AMB_PROJETOS SMALLINT,
      IN_EDUC_AMB_NENHUMA SMALLINT,
      TP_AEE SMALLINT,
      TP_ATIVIDADE_COMPLEMENTAR SMALLINT,
      TP_ITINERARIO_FORMATIVO SMALLINT,
      IN_ITINERARIO_APROFUNDAMENTO SMALLINT,
      IN_ITINERARIO_TECN_PROF SMALLINT,
      IN_ESCOLARIZACAO SMALLINT,
      IN_MEDIACAO_PRESENCIAL SMALLINT,
      IN_MEDIACAO_SEMIPRESENCIAL SMALLINT,
      IN_MEDIACAO_EAD SMALLINT,
      IN_ESPECIAL_EXCLUSIVA SMALLINT,
      IN_REGULAR SMALLINT,
      IN_EJA SMALLINT,
      IN_PROFISSIONALIZANTE SMALLINT,
      IN_COMUM_CRECHE SMALLINT,
      IN_COMUM_PRE SMALLINT,
      IN_COMUM_FUND_AI SMALLINT,
      IN_COMUM_FUND_AF SMALLINT,
      IN_COMUM_MEDIO_MEDIO SMALLINT,
      IN_COMUM_MEDIO_INTEGRADO SMALLINT,
      IN_COMUM_MEDIO_FIC SMALLINT,
      IN_COMUM_MEDIO_NORMAL SMALLINT,
      IN_ESP_EXCLUSIVA_CRECHE SMALLINT,
      IN_ESP_EXCLUSIVA_PRE SMALLINT,
      IN_ESP_EXCLUSIVA_FUND_AI SMALLINT,
      IN_ESP_EXCLUSIVA_FUND_AF SMALLINT,
      IN_ESP_EXCLUSIVA_MEDIO_MEDIO SMALLINT,
      IN_ESP_EXCLUSIVA_MEDIO_INTEGR SMALLINT,
      IN_ESP_EXCLUSIVA_MEDIO_FIC SMALLINT,
      IN_ESP_EXCLUSIVA_MEDIO_NORMAL SMALLINT,
      IN_COMUM_EJA_FUND SMALLINT,
      IN_COMUM_EJA_MEDIO SMALLINT,
      IN_COMUM_EJA_PROF SMALLINT,
      IN_ESP_EXCLUSIVA_EJA_FUND SMALLINT,
      IN_ESP_EXCLUSIVA_EJA_MEDIO SMALLINT,
      IN_ESP_EXCLUSIVA_EJA_PROF SMALLINT,
      IN_COMUM_PROF SMALLINT,
      IN_ESP_EXCLUSIVA_PROF SMALLINT
  );

  -- =================================================================
  -- COMENTÁRIOS DAS COLUNAS
  -- =================================================================

  COMMENT ON COLUMN clean.censo_escolas.linha_id IS 'Número da linha no arquivo original (1 = primeira linha de dados)';
  COMMENT ON COLUMN clean.censo_escolas.NU_ANO_CENSO IS 'Ano de referência do Censo Escolar (ex: 2025)';
  COMMENT ON COLUMN clean.censo_escolas.NO_REGIAO IS 'Nome da região geográfica (Norte, Nordeste, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.CO_REGIAO IS 'Código da região (1-Norte,2-Nordeste,3-Sudeste,4-Sul,5-Centro-Oeste)';
  COMMENT ON COLUMN clean.censo_escolas.NO_UF IS 'Nome da Unidade da Federação';
  COMMENT ON COLUMN clean.censo_escolas.SG_UF IS 'Sigla da UF (SP, RJ, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.CO_UF IS 'Código IBGE da UF';
  COMMENT ON COLUMN clean.censo_escolas.NO_MUNICIPIO IS 'Nome do município';
  COMMENT ON COLUMN clean.censo_escolas.CO_MUNICIPIO IS 'Código IBGE do município';
  COMMENT ON COLUMN clean.censo_escolas.NO_REGIAO_GEOG_INTERM IS 'Nome da região geográfica intermediária (IBGE)';
  COMMENT ON COLUMN clean.censo_escolas.CO_REGIAO_GEOG_INTERM IS 'Código da região intermediária';
  COMMENT ON COLUMN clean.censo_escolas.NO_REGIAO_GEOG_IMED IS 'Nome da região geográfica imediata (IBGE)';
  COMMENT ON COLUMN clean.censo_escolas.CO_REGIAO_GEOG_IMED IS 'Código da região imediata';
  COMMENT ON COLUMN clean.censo_escolas.NO_MESORREGIAO IS 'Nome da mesorregião (IBGE)';
  COMMENT ON COLUMN clean.censo_escolas.CO_MESORREGIAO IS 'Código da mesorregião';
  COMMENT ON COLUMN clean.censo_escolas.NO_MICRORREGIAO IS 'Nome da microrregião (IBGE)';
  COMMENT ON COLUMN clean.censo_escolas.CO_MICRORREGIAO IS 'Código da microrregião';
  COMMENT ON COLUMN clean.censo_escolas.NO_DISTRITO IS 'Nome do distrito (se aplicável)';
  COMMENT ON COLUMN clean.censo_escolas.CO_DISTRITO IS 'Código do distrito';
  COMMENT ON COLUMN clean.censo_escolas.NO_REGIAO_ADMINISTRATIVA IS 'Nome da região administrativa (grandes municípios)';
  COMMENT ON COLUMN clean.censo_escolas.CO_REGIAO_ADMINISTRATIVA IS 'Código da região administrativa';
  COMMENT ON COLUMN clean.censo_escolas.NO_ENTIDADE IS 'Nome oficial da escola';
  COMMENT ON COLUMN clean.censo_escolas.CO_ENTIDADE IS 'Código único da escola no INEP (identificador principal)';
  COMMENT ON COLUMN clean.censo_escolas.TP_DEPENDENCIA IS 'Dependência administrativa: 1-Federal,2-Estadual,3-Municipal,4-Privada';
  COMMENT ON COLUMN clean.censo_escolas.TP_CATEGORIA_ESCOLA_PRIVADA IS 'Categoria da escola privada: 1-Particular,2-Comunitária,3-Confessional,4-Filantrópica';
  COMMENT ON COLUMN clean.censo_escolas.TP_LOCALIZACAO IS 'Localização: 1-Urbana,2-Rural';
  COMMENT ON COLUMN clean.censo_escolas.TP_LOCALIZACAO_DIFERENCIADA IS 'Localização diferenciada: 1-Assentamento,2-Terra Indígena,3-Quilombo,4-Área remanescente de quilombos, etc.';
  COMMENT ON COLUMN clean.censo_escolas.DS_ENDERECO IS 'Logradouro do endereço';
  COMMENT ON COLUMN clean.censo_escolas.NU_ENDERECO IS 'Número do endereço (pode conter letras)';
  COMMENT ON COLUMN clean.censo_escolas.DS_COMPLEMENTO IS 'Complemento do endereço (bloco, apto, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.NO_BAIRRO IS 'Bairro';
  COMMENT ON COLUMN clean.censo_escolas.CO_CEP IS 'Código postal (CEP)';
  COMMENT ON COLUMN clean.censo_escolas.NU_DDD IS 'DDD do telefone';
  COMMENT ON COLUMN clean.censo_escolas.NU_TELEFONE IS 'Número do telefone';
  COMMENT ON COLUMN clean.censo_escolas.LATITUDE IS 'Coordenada latitude (graus decimais)';
  COMMENT ON COLUMN clean.censo_escolas.LONGITUDE IS 'Coordenada longitude (graus decimais)';
  COMMENT ON COLUMN clean.censo_escolas.TP_SITUACAO_FUNCIONAMENTO IS 'Situação de funcionamento: 1-Ativa,2-Paralisada,3-Extinta';
  COMMENT ON COLUMN clean.censo_escolas.CO_ORGAO_REGIONAL IS 'Código do órgão regional de educação (CRE, DRES, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.DT_ANO_LETIVO_INICIO IS 'Data de início do ano letivo (formato DD/MM/AAAA)';
  COMMENT ON COLUMN clean.censo_escolas.DT_ANO_LETIVO_TERMINO IS 'Data de término do ano letivo (formato DD/MM/AAAA)';
  COMMENT ON COLUMN clean.censo_escolas.IN_VINCULO_SECRETARIA_EDUCACAO IS 'A escola tem vínculo com a Secretaria de Educação? (0-Não,1-Sim)';
  COMMENT ON COLUMN clean.censo_escolas.IN_VINCULO_SEGURANCA_PUBLICA IS 'Vínculo com órgão de segurança pública?';
  COMMENT ON COLUMN clean.censo_escolas.IN_VINCULO_SECRETARIA_SAUDE IS 'Vínculo com Secretaria de Saúde?';
  COMMENT ON COLUMN clean.censo_escolas.IN_VINCULO_OUTRO_ORGAO IS 'Vínculo com outro órgão público?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PODER_PUBLICO_PARCERIA IS 'Mantém parceria com o poder público?';
  COMMENT ON COLUMN clean.censo_escolas.TP_PODER_PUBLICO_PARCERIA IS 'Tipo de poder público parceiro: 1-Municipal,2-Estadual,3-Federal';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_TERMO_COLABORA IS 'Forma de contrato: termo de colaboração? (0/1)';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_TERMO_FOMENTO IS 'Forma de contrato: termo de fomento?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ACORDO_COOP IS 'Forma de contrato: acordo de cooperação?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_PRESTACAO_SERV IS 'Forma de contrato: prestação de serviços?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_COOP_TEC_FIN IS 'Forma de contrato: cooperação técnica/financeira?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_CONSORCIO_PUB IS 'Forma de contrato: consórcio público?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_TERMO_COLAB IS 'Forma de contrato (municipal): termo de colaboração?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_TERMO_FOMENTO IS 'Forma de contrato (municipal): termo de fomento?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_ACORDO_COOP IS 'Forma de contrato (municipal): acordo de cooperação?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_PREST_SERV IS 'Forma de contrato (municipal): prestação de serviços?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_COOP_TEC_FIN IS 'Forma de contrato (municipal): cooperação técnico-financeira?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_MU_CONSORCIO_PUB IS 'Forma de contrato (municipal): consórcio público?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_TERMO_COLAB IS 'Forma de contrato (estadual): termo de colaboração?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_TERMO_FOMENTO IS 'Forma de contrato (estadual): termo de fomento?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_ACORDO_COOP IS 'Forma de contrato (estadual): acordo de cooperação?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_PREST_SERV IS 'Forma de contrato (estadual): prestação de serviços?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_COOP_TEC_FIN IS 'Forma de contrato (estadual): cooperação técnico-financeira?';
  COMMENT ON COLUMN clean.censo_escolas.IN_FORMA_CONT_ES_CONSORCIO_PUB IS 'Forma de contrato (estadual): consórcio público?';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_EMP IS 'Mantenedora privada: empresa (0/1)';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_ONG IS 'Mantenedora: ONG';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_OSCIP IS 'Mantenedora: OSCIP';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIV_ONG_OSCIP IS 'Mantenedora: ONG ou OSCIP';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_SIND IS 'Mantenedora: sindicato';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_SIST_S IS 'Mantenedora: Sistema S (SESI, SENAI, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.IN_MANT_ESCOLA_PRIVADA_S_FINS IS 'Mantenedora: sem fins lucrativos';
  COMMENT ON COLUMN clean.censo_escolas.NU_CNPJ_ESCOLA_PRIVADA IS 'CNPJ da escola privada';
  COMMENT ON COLUMN clean.censo_escolas.NU_CNPJ_MANTENEDORA IS 'CNPJ da mantenedora (privada)';
  COMMENT ON COLUMN clean.censo_escolas.TP_REGULAMENTACAO IS 'Tipo de regulamentação da escola (estadual, municipal, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.TP_RESPONSAVEL_REGULAMENTACAO IS 'Responsável pela regulamentação';
  COMMENT ON COLUMN clean.censo_escolas.CO_ESCOLA_SEDE_VINCULADA IS 'Código da escola sede (se esta for extensão)';
  COMMENT ON COLUMN clean.censo_escolas.CO_IES_OFERTANTE IS 'Código da IES ofertante (educação profissional)';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_PREDIO_ESCOLAR IS 'Funciona em prédio escolar? (0/1)';
  COMMENT ON COLUMN clean.censo_escolas.TP_OCUPACAO_PREDIO_ESCOLAR IS 'Tipo de ocupação do prédio (próprio, alugado, cedido)';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_SOCIOEDUCATIVO IS 'Funciona em unidade socioeducativa?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_UNID_PRISIONAL IS 'Funciona em unidade prisional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_PRISIONAL_SOCIO IS 'Funciona em unidade prisional/socioeducativa?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_GALPAO IS 'Funciona em galpão?';
  COMMENT ON COLUMN clean.censo_escolas.TP_OCUPACAO_GALPAO IS 'Tipo de ocupação do galpão';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_SALAS_OUTRA_ESC IS 'Funciona em salas de outra escola?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LOCAL_FUNC_OUTROS IS 'Funciona em outro tipo de local?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PREDIO_COMPARTILHADO IS 'Prédio compartilhado com outra escola?';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_POTAVEL IS 'Há água potável na escola?';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_REDE_PUBLICA IS 'Abastecimento de água: rede pública';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_POCO_ARTESIANO IS 'Abastecimento: poço artesiano';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_CACIMBA IS 'Abastecimento: cacimba';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_FONTE_RIO IS 'Abastecimento: fonte/rio';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_INEXISTENTE IS 'Inexistente abastecimento de água';
  COMMENT ON COLUMN clean.censo_escolas.IN_AGUA_CARRO_PIPA IS 'Abastecimento: carro-pipa';
  COMMENT ON COLUMN clean.censo_escolas.IN_ENERGIA_REDE_PUBLICA IS 'Energia elétrica: rede pública';
  COMMENT ON COLUMN clean.censo_escolas.IN_ENERGIA_GERADOR_FOSSIL IS 'Energia: gerador a combustível fóssil';
  COMMENT ON COLUMN clean.censo_escolas.IN_ENERGIA_RENOVAVEL IS 'Energia: fonte renovável (solar, eólica)';
  COMMENT ON COLUMN clean.censo_escolas.IN_ENERGIA_INEXISTENTE IS 'Inexistente energia elétrica';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESGOTO_REDE_PUBLICA IS 'Esgoto sanitário: rede pública';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESGOTO_FOSSA_SEPTICA IS 'Esgoto: fossa séptica';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESGOTO_FOSSA_COMUM IS 'Esgoto: fossa comum';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESGOTO_FOSSA IS 'Esgoto: fossa (genérico)';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESGOTO_INEXISTENTE IS 'Inexistente esgotamento sanitário';
  COMMENT ON COLUMN clean.censo_escolas.IN_LIXO_SERVICO_COLETA IS 'Destino do lixo: serviço de coleta';
  COMMENT ON COLUMN clean.censo_escolas.IN_LIXO_QUEIMA IS 'Destino: queima';
  COMMENT ON COLUMN clean.censo_escolas.IN_LIXO_ENTERRA IS 'Destino: enterra';
  COMMENT ON COLUMN clean.censo_escolas.IN_LIXO_DESTINO_FINAL_PUBLICO IS 'Destino: destino final público (lixão/aterro)';
  COMMENT ON COLUMN clean.censo_escolas.IN_LIXO_DESCARTA_OUTRA_AREA IS 'Destino: descarta em outra área';
  COMMENT ON COLUMN clean.censo_escolas.IN_TRATAMENTO_LIXO_SEPARACAO IS 'Tratamento do lixo: separação';
  COMMENT ON COLUMN clean.censo_escolas.IN_TRATAMENTO_LIXO_REUTILIZA IS 'Tratamento: reutilização';
  COMMENT ON COLUMN clean.censo_escolas.IN_TRATAMENTO_LIXO_RECICLAGEM IS 'Tratamento: reciclagem';
  COMMENT ON COLUMN clean.censo_escolas.IN_TRATAMENTO_LIXO_INEXISTENTE IS 'Inexistente tratamento de lixo';
  COMMENT ON COLUMN clean.censo_escolas.IN_ALMOXARIFADO IS 'Possui almoxarifado?';
  COMMENT ON COLUMN clean.censo_escolas.IN_AREA_VERDE IS 'Possui área verde?';
  COMMENT ON COLUMN clean.censo_escolas.IN_AREA_PLANTIO IS 'Possui área de plantio?';
  COMMENT ON COLUMN clean.censo_escolas.IN_AUDITORIO IS 'Possui auditório?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANHEIRO IS 'Possui banheiro?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANHEIRO_EI IS 'Banheiro para educação infantil?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANHEIRO_PNE IS 'Banheiro acessível para PNE?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANHEIRO_FUNCIONARIOS IS 'Banheiro para funcionários?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANHEIRO_CHUVEIRO IS 'Banheiro com chuveiro?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BIBLIOTECA IS 'Possui biblioteca?';
  COMMENT ON COLUMN clean.censo_escolas.IN_BIBLIOTECA_SALA_LEITURA IS 'Possui biblioteca ou sala de leitura?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COZINHA IS 'Possui cozinha?';
  COMMENT ON COLUMN clean.censo_escolas.IN_DESPENSA IS 'Possui despensa?';
  COMMENT ON COLUMN clean.censo_escolas.IN_DORMITORIO_ALUNO IS 'Possui dormitório para alunos?';
  COMMENT ON COLUMN clean.censo_escolas.IN_DORMITORIO_PROFESSOR IS 'Possui dormitório para professores?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LABORATORIO_CIENCIAS IS 'Possui laboratório de ciências?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LABORATORIO_INFORMATICA IS 'Possui laboratório de informática?';
  COMMENT ON COLUMN clean.censo_escolas.IN_LABORATORIO_EDUC_PROF IS 'Possui laboratório de educação profissional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PATIO_COBERTO IS 'Possui pátio coberto?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PATIO_DESCOBERTO IS 'Possui pátio descoberto?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PARQUE_INFANTIL IS 'Possui parque infantil?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PISCINA IS 'Possui piscina?';
  COMMENT ON COLUMN clean.censo_escolas.IN_QUADRA_ESPORTES IS 'Possui quadra de esportes?';
  COMMENT ON COLUMN clean.censo_escolas.IN_QUADRA_ESPORTES_COBERTA IS 'Quadra coberta?';
  COMMENT ON COLUMN clean.censo_escolas.IN_QUADRA_ESPORTES_DESCOBERTA IS 'Quadra descoberta?';
  COMMENT ON COLUMN clean.censo_escolas.IN_REFEITORIO IS 'Possui refeitório?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_ATELIE_ARTES IS 'Possui sala/atelier de artes?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_MUSICA_CORAL IS 'Possui sala de música/coral?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_ESTUDIO_DANCA IS 'Possui sala/estúdio de dança?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_MULTIUSO IS 'Possui sala multiuso?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_ESTUDIO_GRAVACAO IS 'Possui estúdio de gravação?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_OFICINAS_EDUC_PROF IS 'Possui sala de oficinas de educação profissional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_DIRETORIA IS 'Possui sala da diretoria?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_LEITURA IS 'Possui sala de leitura?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_PROFESSOR IS 'Possui sala dos professores?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_REPOUSO_ALUNO IS 'Possui sala de repouso para alunos?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SECRETARIA IS 'Possui secretaria?';
  COMMENT ON COLUMN clean.censo_escolas.IN_SALA_ATENDIMENTO_ESPECIAL IS 'Possui sala de atendimento especial?';
  COMMENT ON COLUMN clean.censo_escolas.IN_TERREIRAO IS 'Possui terreirão (espaço aberto)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_VIVEIRO IS 'Possui viveiro (plantas)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_DEPENDENCIAS_OUTRAS IS 'Possui outras dependências não listadas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_CORRIMAO IS 'Acessibilidade: corrimão?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_ELEVADOR IS 'Acessibilidade: elevador?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_PISOS_TATEIS IS 'Acessibilidade: pisos táteis?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_VAO_LIVRE IS 'Acessibilidade: vão livre (portas largas)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_RAMPAS IS 'Acessibilidade: rampas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_SINAL_SONORO IS 'Acessibilidade: sinal sonoro?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_SINAL_TATIL IS 'Acessibilidade: sinal tátil?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_SINAL_VISUAL IS 'Acessibilidade: sinal visual?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_INEXISTENTE IS 'Inexistente recursos de acessibilidade?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSIBILIDADE_SINALIZACAO IS 'Acessibilidade: sinalização adequada?';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_UTILIZADAS_DENTRO IS 'Quantidade de salas de aula utilizadas na própria escola';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_UTILIZADAS_FORA IS 'Quantidade de salas de aula utilizadas fora da escola';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_UTILIZADAS IS 'Quantidade total de salas de aula utilizadas';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_UTILIZA_CLIMATIZADAS IS 'Quantidade de salas de aula climatizadas';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_UTILIZADAS_ACESSIVEIS IS 'Quantidade de salas acessíveis para PNE';
  COMMENT ON COLUMN clean.censo_escolas.QT_SALAS_LEITURA IS 'Quantidade de salas de leitura';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_PARABOLICA IS 'Dispõe de antena parabólica?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMPUTADOR IS 'Dispõe de computadores?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_COPIADORA IS 'Dispõe de copiadora?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_IMPRESSORA IS 'Dispõe de impressora?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_IMPRESSORA_MULT IS 'Dispõe de impressora multifuncional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_SCANNER IS 'Dispõe de scanner?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_NENHUM IS 'Não dispõe de nenhum desses equipamentos?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_DVD IS 'Dispõe de equipamento de DVD?';
  COMMENT ON COLUMN clean.censo_escolas.QT_EQUIP_DVD IS 'Quantidade de aparelhos de DVD';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_SOM IS 'Dispõe de equipamento de som?';
  COMMENT ON COLUMN clean.censo_escolas.QT_EQUIP_SOM IS 'Quantidade de equipamentos de som';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_TV IS 'Dispõe de televisão?';
  COMMENT ON COLUMN clean.censo_escolas.QT_EQUIP_TV IS 'Quantidade de televisores';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_LOUSA_DIGITAL IS 'Dispõe de lousa digital?';
  COMMENT ON COLUMN clean.censo_escolas.QT_EQUIP_LOUSA_DIGITAL IS 'Quantidade de lousas digitais';
  COMMENT ON COLUMN clean.censo_escolas.IN_EQUIP_MULTIMIDIA IS 'Dispõe de equipamento multimídia (projetor, etc.)?';
  COMMENT ON COLUMN clean.censo_escolas.QT_EQUIP_MULTIMIDIA IS 'Quantidade de equipamentos multimídia';
  COMMENT ON COLUMN clean.censo_escolas.IN_DESKTOP_ALUNO IS 'Dispõe de computadores desktop para alunos?';
  COMMENT ON COLUMN clean.censo_escolas.QT_DESKTOP_ALUNO IS 'Quantidade de desktops para alunos';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMP_PORTATIL_ALUNO IS 'Dispõe de computadores portáteis (notebooks) para alunos?';
  COMMENT ON COLUMN clean.censo_escolas.QT_COMP_PORTATIL_ALUNO IS 'Quantidade de portáteis para alunos';
  COMMENT ON COLUMN clean.censo_escolas.IN_TABLET_ALUNO IS 'Dispõe de tablets para alunos?';
  COMMENT ON COLUMN clean.censo_escolas.QT_TABLET_ALUNO IS 'Quantidade de tablets para alunos';
  COMMENT ON COLUMN clean.censo_escolas.IN_INTERNET IS 'Acesso à internet na escola?';
  COMMENT ON COLUMN clean.censo_escolas.IN_INTERNET_ALUNOS IS 'Uso da internet para atividades dos alunos?';
  COMMENT ON COLUMN clean.censo_escolas.IN_INTERNET_ADMINISTRATIVO IS 'Uso da internet para atividades administrativas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_INTERNET_APRENDIZAGEM IS 'Uso da internet na aprendizagem?';
  COMMENT ON COLUMN clean.censo_escolas.IN_INTERNET_COMUNIDADE IS 'Uso da internet pela comunidade?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACESSO_INTERNET_COMPUTADOR IS 'Acesso à internet via computador';
  COMMENT ON COLUMN clean.censo_escolas.IN_ACES_INTERNET_DISP_PESSOAIS IS 'Acesso à internet via dispositivos pessoais';
  COMMENT ON COLUMN clean.censo_escolas.TP_REDE_LOCAL IS 'Tipo de rede local: 0-inexistente,1-com fio,2-wifi,3-ambas';
  COMMENT ON COLUMN clean.censo_escolas.IN_BANDA_LARGA IS 'Conexão de banda larga?';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_ADMINISTRATIVOS IS 'Quantidade de profissionais administrativos';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_SERVICOS_GERAIS IS 'Quantidade de profissionais de serviços gerais';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_BIBLIOTECARIO IS 'Quantidade de bibliotecários';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_SAUDE IS 'Quantidade de profissionais de saúde (enfermagem, etc.)';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_COORDENADOR IS 'Quantidade de coordenadores';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_FONAUDIOLOGO IS 'Quantidade de fonoaudiólogos';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_NUTRICIONISTA IS 'Quantidade de nutricionistas';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_PSICOLOGO IS 'Quantidade de psicólogos';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_ALIMENTACAO IS 'Quantidade de profissionais de alimentação';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_PEDAGOGIA IS 'Quantidade de pedagogos';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_SECRETARIO IS 'Quantidade de secretários';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_SEGURANCA IS 'Quantidade de profissionais de segurança';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_MONITORES IS 'Quantidade de monitores';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_GESTAO IS 'Quantidade de profissionais de gestão';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_ASSIST_SOCIAL IS 'Quantidade de assistentes sociais';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_TRAD_LIBRAS IS 'Quantidade de tradutores/intérpretes de Libras';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_AGRICOLA IS 'Quantidade de profissionais agrícolas';
  COMMENT ON COLUMN clean.censo_escolas.QT_PROF_REVISOR_BRAILLE IS 'Quantidade de revisores de Braille';
  COMMENT ON COLUMN clean.censo_escolas.IN_ALIMENTACAO IS 'Oferece alimentação escolar?';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_MULTIMIDIA IS 'Materiais pedagógicos: multimídia';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_INFANTIL IS 'Materiais: educação infantil';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_CIENTIFICO IS 'Materiais: científico';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_DIFUSAO IS 'Materiais: difusão (cultura geral)';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_MUSICAL IS 'Materiais: musical';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_JOGOS IS 'Materiais: jogos educativos';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_ARTISTICAS IS 'Materiais: artes';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_PROFISSIONAL IS 'Materiais: profissionalizante';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_DESPORTIVA IS 'Materiais: esportiva';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_INDIGENA IS 'Materiais: indígena';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_ETNICO IS 'Materiais: étnico-racial';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_CAMPO IS 'Materiais: educação do campo';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_BIL_SURDOS IS 'Materiais: bilíngue para surdos';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_AGRICOLA IS 'Materiais: agrícola';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_QUILOMBOLA IS 'Materiais: quilombola';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_EDU_ESP IS 'Materiais: educação especial';
  COMMENT ON COLUMN clean.censo_escolas.IN_MATERIAL_PED_NENHUM IS 'Nenhum material pedagógico listado';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUCACAO_INDIGENA IS 'Oferece educação indígena específica?';
  COMMENT ON COLUMN clean.censo_escolas.TP_INDIGENA_LINGUA IS 'Língua usada na educação indígena: 1-indígena,2-português,3-ambas';
  COMMENT ON COLUMN clean.censo_escolas.CO_LINGUA_INDIGENA_1 IS 'Código da primeira língua indígena usada';
  COMMENT ON COLUMN clean.censo_escolas.CO_LINGUA_INDIGENA_2 IS 'Código da segunda língua indígena usada';
  COMMENT ON COLUMN clean.censo_escolas.CO_LINGUA_INDIGENA_3 IS 'Código da terceira língua indígena usada';
  COMMENT ON COLUMN clean.censo_escolas.IN_EXAME_SELECAO IS 'Utiliza processo seletivo para ingresso?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_PPI IS 'Possui reserva de vagas para pretos, pardos e indígenas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_RENDA IS 'Reserva de vagas por critério de renda?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_PUBLICA IS 'Reserva de vagas para egressos de escola pública?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_PCD IS 'Reserva de vagas para pessoas com deficiência?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_OUTROS IS 'Outros tipos de reserva de vagas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_RESERVA_NENHUMA IS 'Nenhuma reserva de vagas?';
  COMMENT ON COLUMN clean.censo_escolas.IN_REDES_SOCIAIS IS 'Possui perfil oficial em redes sociais?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESPACO_ATIVIDADE IS 'Possui espaços para atividades complementares?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESPACO_EQUIPAMENTO IS 'Possui equipamentos para atividades complementares?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_ASS_PAIS IS 'Possui associação de pais?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_ASS_PAIS_MESTRES IS 'Possui associação de pais e mestres?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_CONSELHO_ESCOLAR IS 'Possui conselho escolar?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_GREMIO_ESTUDANTIL IS 'Possui grêmio estudantil?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_OUTROS IS 'Possui outros órgãos colegiados?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ORGAO_NENHUM IS 'Nenhum órgão colegiado?';
  COMMENT ON COLUMN clean.censo_escolas.TP_PROPOSTA_PEDAGOGICA IS 'Tipo de proposta pedagógica: 1-Própria,2-Da rede,3-Adaptada da rede';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMBIENTAL IS 'Aborda educação ambiental?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_CONTEUDO IS 'Educação ambiental como conteúdo?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_CURRICULAR IS 'Educação ambiental na matriz curricular?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_EIXO IS 'Educação ambiental como eixo transversal?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_EVENTOS IS 'Atividades de educação ambiental em eventos?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_PROJETOS IS 'Projetos de educação ambiental?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EDUC_AMB_NENHUMA IS 'Nenhuma abordagem de educação ambiental';
  COMMENT ON COLUMN clean.censo_escolas.TP_AEE IS 'Tipo de Atendimento Educacional Especializado: 1-Sala multifuncional,2-Outras salas,3-Canto de atividades,4-Itinerância,5-Classe hospitalar,8-Não se aplica';
  COMMENT ON COLUMN clean.censo_escolas.TP_ATIVIDADE_COMPLEMENTAR IS 'Tipo de atividade complementar: 1-Meio período,2-Período integral,3-Ambas';
  COMMENT ON COLUMN clean.censo_escolas.TP_ITINERARIO_FORMATIVO IS 'Itinerário formativo (Novo EM): 1-Linguagens,2-Matemática,3-Ciências da Natureza,4-Ciências Humanas,5-Técnico profissional';
  COMMENT ON COLUMN clean.censo_escolas.IN_ITINERARIO_APROFUNDAMENTO IS 'Itinerário de aprofundamento?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ITINERARIO_TECN_PROF IS 'Itinerário técnico-profissional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESCOLARIZACAO IS 'Promove escolarização?';
  COMMENT ON COLUMN clean.censo_escolas.IN_MEDIACAO_PRESENCIAL IS 'Mediação presencial';
  COMMENT ON COLUMN clean.censo_escolas.IN_MEDIACAO_SEMIPRESENCIAL IS 'Mediação semipresencial';
  COMMENT ON COLUMN clean.censo_escolas.IN_MEDIACAO_EAD IS 'Mediação a distância (EAD)';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESPECIAL_EXCLUSIVA IS 'Oferece educação especial exclusiva?';
  COMMENT ON COLUMN clean.censo_escolas.IN_REGULAR IS 'Oferece ensino regular?';
  COMMENT ON COLUMN clean.censo_escolas.IN_EJA IS 'Oferece Educação de Jovens e Adultos (EJA)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_PROFISSIONALIZANTE IS 'Oferece educação profissional?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_CRECHE IS 'Oferece creche (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_PRE IS 'Oferece pré-escola (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_FUND_AI IS 'Oferece ensino fundamental anos iniciais (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_FUND_AF IS 'Oferece ensino fundamental anos finais (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_MEDIO_MEDIO IS 'Oferece ensino médio regular?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_MEDIO_INTEGRADO IS 'Oferece ensino médio integrado (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_MEDIO_FIC IS 'Oferece ensino médio - FIC (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_MEDIO_NORMAL IS 'Oferece curso normal (magistério) em nível médio?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_CRECHE IS 'Oferece creche (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_PRE IS 'Oferece pré-escola (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_FUND_AI IS 'Oferece ensino fundamental AI (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_FUND_AF IS 'Oferece ensino fundamental AF (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_MEDIO_MEDIO IS 'Oferece ensino médio (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_MEDIO_INTEGR IS 'Oferece ensino médio integrado (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_MEDIO_FIC IS 'Oferece ensino médio FIC (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_MEDIO_NORMAL IS 'Oferece curso normal (magistério) em nível médio (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_EJA_FUND IS 'Oferece EJA fundamental (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_EJA_MEDIO IS 'Oferece EJA médio (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_EJA_PROF IS 'Oferece EJA profissionalizante (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_EJA_FUND IS 'Oferece EJA fundamental (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_EJA_MEDIO IS 'Oferece EJA médio (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_EJA_PROF IS 'Oferece EJA profissional (educação especial exclusiva)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_COMUM_PROF IS 'Oferece educação profissional (regular)?';
  COMMENT ON COLUMN clean.censo_escolas.IN_ESP_EXCLUSIVA_PROF IS 'Oferece educação profissional (educação especial exclusiva)?';

  -- =================================================================
  -- COPY dos dados (assumindo arquivo UTF-8 com cabeçalho)
  -- =================================================================

  COPY clean.censo_escolas (
      NU_ANO_CENSO, NO_REGIAO, CO_REGIAO, NO_UF, SG_UF, CO_UF, NO_MUNICIPIO, CO_MUNICIPIO,
      NO_REGIAO_GEOG_INTERM, CO_REGIAO_GEOG_INTERM, NO_REGIAO_GEOG_IMED, CO_REGIAO_GEOG_IMED,
      NO_MESORREGIAO, CO_MESORREGIAO, NO_MICRORREGIAO, CO_MICRORREGIAO,
      NO_DISTRITO, CO_DISTRITO, NO_REGIAO_ADMINISTRATIVA, CO_REGIAO_ADMINISTRATIVA,
      NO_ENTIDADE, CO_ENTIDADE, TP_DEPENDENCIA, TP_CATEGORIA_ESCOLA_PRIVADA, TP_LOCALIZACAO,
      TP_LOCALIZACAO_DIFERENCIADA, DS_ENDERECO, NU_ENDERECO, DS_COMPLEMENTO, NO_BAIRRO, CO_CEP,
      NU_DDD, NU_TELEFONE, LATITUDE, LONGITUDE, TP_SITUACAO_FUNCIONAMENTO, CO_ORGAO_REGIONAL,
      DT_ANO_LETIVO_INICIO, DT_ANO_LETIVO_TERMINO,
      IN_VINCULO_SECRETARIA_EDUCACAO, IN_VINCULO_SEGURANCA_PUBLICA, IN_VINCULO_SECRETARIA_SAUDE, IN_VINCULO_OUTRO_ORGAO,
      IN_PODER_PUBLICO_PARCERIA, TP_PODER_PUBLICO_PARCERIA,
      IN_FORMA_CONT_TERMO_COLABORA, IN_FORMA_CONT_TERMO_FOMENTO, IN_FORMA_CONT_ACORDO_COOP, IN_FORMA_CONT_PRESTACAO_SERV,
      IN_FORMA_CONT_COOP_TEC_FIN, IN_FORMA_CONT_CONSORCIO_PUB,
      IN_FORMA_CONT_MU_TERMO_COLAB, IN_FORMA_CONT_MU_TERMO_FOMENTO, IN_FORMA_CONT_MU_ACORDO_COOP, IN_FORMA_CONT_MU_PREST_SERV,
      IN_FORMA_CONT_MU_COOP_TEC_FIN, IN_FORMA_CONT_MU_CONSORCIO_PUB,
      IN_FORMA_CONT_ES_TERMO_COLAB, IN_FORMA_CONT_ES_TERMO_FOMENTO, IN_FORMA_CONT_ES_ACORDO_COOP, IN_FORMA_CONT_ES_PREST_SERV,
      IN_FORMA_CONT_ES_COOP_TEC_FIN, IN_FORMA_CONT_ES_CONSORCIO_PUB,
      IN_MANT_ESCOLA_PRIVADA_EMP, IN_MANT_ESCOLA_PRIVADA_ONG, IN_MANT_ESCOLA_PRIVADA_OSCIP, IN_MANT_ESCOLA_PRIV_ONG_OSCIP,
      IN_MANT_ESCOLA_PRIVADA_SIND, IN_MANT_ESCOLA_PRIVADA_SIST_S, IN_MANT_ESCOLA_PRIVADA_S_FINS,
      NU_CNPJ_ESCOLA_PRIVADA, NU_CNPJ_MANTENEDORA, TP_REGULAMENTACAO, TP_RESPONSAVEL_REGULAMENTACAO,
      CO_ESCOLA_SEDE_VINCULADA, CO_IES_OFERTANTE,
      IN_LOCAL_FUNC_PREDIO_ESCOLAR, TP_OCUPACAO_PREDIO_ESCOLAR, IN_LOCAL_FUNC_SOCIOEDUCATIVO, IN_LOCAL_FUNC_UNID_PRISIONAL,
      IN_LOCAL_FUNC_PRISIONAL_SOCIO, IN_LOCAL_FUNC_GALPAO, TP_OCUPACAO_GALPAO, IN_LOCAL_FUNC_SALAS_OUTRA_ESC, IN_LOCAL_FUNC_OUTROS,
      IN_PREDIO_COMPARTILHADO,
      IN_AGUA_POTAVEL, IN_AGUA_REDE_PUBLICA, IN_AGUA_POCO_ARTESIANO, IN_AGUA_CACIMBA, IN_AGUA_FONTE_RIO, IN_AGUA_INEXISTENTE, IN_AGUA_CARRO_PIPA,
      IN_ENERGIA_REDE_PUBLICA, IN_ENERGIA_GERADOR_FOSSIL, IN_ENERGIA_RENOVAVEL, IN_ENERGIA_INEXISTENTE,
      IN_ESGOTO_REDE_PUBLICA, IN_ESGOTO_FOSSA_SEPTICA, IN_ESGOTO_FOSSA_COMUM, IN_ESGOTO_FOSSA, IN_ESGOTO_INEXISTENTE,
      IN_LIXO_SERVICO_COLETA, IN_LIXO_QUEIMA, IN_LIXO_ENTERRA, IN_LIXO_DESTINO_FINAL_PUBLICO, IN_LIXO_DESCARTA_OUTRA_AREA,
      IN_TRATAMENTO_LIXO_SEPARACAO, IN_TRATAMENTO_LIXO_REUTILIZA, IN_TRATAMENTO_LIXO_RECICLAGEM, IN_TRATAMENTO_LIXO_INEXISTENTE,
      IN_ALMOXARIFADO, IN_AREA_VERDE, IN_AREA_PLANTIO, IN_AUDITORIO, IN_BANHEIRO, IN_BANHEIRO_EI, IN_BANHEIRO_PNE,
      IN_BANHEIRO_FUNCIONARIOS, IN_BANHEIRO_CHUVEIRO, IN_BIBLIOTECA, IN_BIBLIOTECA_SALA_LEITURA, IN_COZINHA, IN_DESPENSA,
      IN_DORMITORIO_ALUNO, IN_DORMITORIO_PROFESSOR, IN_LABORATORIO_CIENCIAS, IN_LABORATORIO_INFORMATICA, IN_LABORATORIO_EDUC_PROF,
      IN_PATIO_COBERTO, IN_PATIO_DESCOBERTO, IN_PARQUE_INFANTIL, IN_PISCINA, IN_QUADRA_ESPORTES, IN_QUADRA_ESPORTES_COBERTA,
      IN_QUADRA_ESPORTES_DESCOBERTA, IN_REFEITORIO, IN_SALA_ATELIE_ARTES, IN_SALA_MUSICA_CORAL, IN_SALA_ESTUDIO_DANCA,
      IN_SALA_MULTIUSO, IN_SALA_ESTUDIO_GRAVACAO, IN_SALA_OFICINAS_EDUC_PROF, IN_SALA_DIRETORIA, IN_SALA_LEITURA,
      IN_SALA_PROFESSOR, IN_SALA_REPOUSO_ALUNO, IN_SECRETARIA, IN_SALA_ATENDIMENTO_ESPECIAL, IN_TERREIRAO, IN_VIVEIRO,
      IN_DEPENDENCIAS_OUTRAS,
      IN_ACESSIBILIDADE_CORRIMAO, IN_ACESSIBILIDADE_ELEVADOR, IN_ACESSIBILIDADE_PISOS_TATEIS, IN_ACESSIBILIDADE_VAO_LIVRE,
      IN_ACESSIBILIDADE_RAMPAS, IN_ACESSIBILIDADE_SINAL_SONORO, IN_ACESSIBILIDADE_SINAL_TATIL, IN_ACESSIBILIDADE_SINAL_VISUAL,
      IN_ACESSIBILIDADE_INEXISTENTE, IN_ACESSIBILIDADE_SINALIZACAO,
      QT_SALAS_UTILIZADAS_DENTRO, QT_SALAS_UTILIZADAS_FORA, QT_SALAS_UTILIZADAS, QT_SALAS_UTILIZA_CLIMATIZADAS, QT_SALAS_UTILIZADAS_ACESSIVEIS,
      QT_SALAS_LEITURA,
      IN_EQUIP_PARABOLICA, IN_COMPUTADOR, IN_EQUIP_COPIADORA, IN_EQUIP_IMPRESSORA, IN_EQUIP_IMPRESSORA_MULT, IN_EQUIP_SCANNER,
      IN_EQUIP_NENHUM, IN_EQUIP_DVD, QT_EQUIP_DVD, IN_EQUIP_SOM, QT_EQUIP_SOM, IN_EQUIP_TV, QT_EQUIP_TV, IN_EQUIP_LOUSA_DIGITAL,
      QT_EQUIP_LOUSA_DIGITAL, IN_EQUIP_MULTIMIDIA, QT_EQUIP_MULTIMIDIA,
      IN_DESKTOP_ALUNO, QT_DESKTOP_ALUNO, IN_COMP_PORTATIL_ALUNO, QT_COMP_PORTATIL_ALUNO, IN_TABLET_ALUNO, QT_TABLET_ALUNO,
      IN_INTERNET, IN_INTERNET_ALUNOS, IN_INTERNET_ADMINISTRATIVO, IN_INTERNET_APRENDIZAGEM, IN_INTERNET_COMUNIDADE,
      IN_ACESSO_INTERNET_COMPUTADOR, IN_ACES_INTERNET_DISP_PESSOAIS, TP_REDE_LOCAL, IN_BANDA_LARGA,
      QT_PROF_ADMINISTRATIVOS, QT_PROF_SERVICOS_GERAIS, QT_PROF_BIBLIOTECARIO, QT_PROF_SAUDE, QT_PROF_COORDENADOR,
      QT_PROF_FONAUDIOLOGO, QT_PROF_NUTRICIONISTA, QT_PROF_PSICOLOGO, QT_PROF_ALIMENTACAO, QT_PROF_PEDAGOGIA,
      QT_PROF_SECRETARIO, QT_PROF_SEGURANCA, QT_PROF_MONITORES, QT_PROF_GESTAO, QT_PROF_ASSIST_SOCIAL, QT_PROF_TRAD_LIBRAS,
      QT_PROF_AGRICOLA, QT_PROF_REVISOR_BRAILLE,
      IN_ALIMENTACAO,
      IN_MATERIAL_PED_MULTIMIDIA, IN_MATERIAL_PED_INFANTIL, IN_MATERIAL_PED_CIENTIFICO, IN_MATERIAL_PED_DIFUSAO,
      IN_MATERIAL_PED_MUSICAL, IN_MATERIAL_PED_JOGOS, IN_MATERIAL_PED_ARTISTICAS, IN_MATERIAL_PED_PROFISSIONAL,
      IN_MATERIAL_PED_DESPORTIVA, IN_MATERIAL_PED_INDIGENA, IN_MATERIAL_PED_ETNICO, IN_MATERIAL_PED_CAMPO,
      IN_MATERIAL_PED_BIL_SURDOS, IN_MATERIAL_PED_AGRICOLA, IN_MATERIAL_PED_QUILOMBOLA, IN_MATERIAL_PED_EDU_ESP,
      IN_MATERIAL_PED_NENHUM,
      IN_EDUCACAO_INDIGENA, TP_INDIGENA_LINGUA, CO_LINGUA_INDIGENA_1, CO_LINGUA_INDIGENA_2, CO_LINGUA_INDIGENA_3,
      IN_EXAME_SELECAO, IN_RESERVA_PPI, IN_RESERVA_RENDA, IN_RESERVA_PUBLICA, IN_RESERVA_PCD, IN_RESERVA_OUTROS, IN_RESERVA_NENHUMA,
      IN_REDES_SOCIAIS, IN_ESPACO_ATIVIDADE, IN_ESPACO_EQUIPAMENTO,
      IN_ORGAO_ASS_PAIS, IN_ORGAO_ASS_PAIS_MESTRES, IN_ORGAO_CONSELHO_ESCOLAR, IN_ORGAO_GREMIO_ESTUDANTIL, IN_ORGAO_OUTROS, IN_ORGAO_NENHUM,
      TP_PROPOSTA_PEDAGOGICA,
      IN_EDUC_AMBIENTAL, IN_EDUC_AMB_CONTEUDO, IN_EDUC_AMB_CURRICULAR, IN_EDUC_AMB_EIXO, IN_EDUC_AMB_EVENTOS, IN_EDUC_AMB_PROJETOS, IN_EDUC_AMB_NENHUMA,
      TP_AEE, TP_ATIVIDADE_COMPLEMENTAR, TP_ITINERARIO_FORMATIVO, IN_ITINERARIO_APROFUNDAMENTO, IN_ITINERARIO_TECN_PROF,
      IN_ESCOLARIZACAO, IN_MEDIACAO_PRESENCIAL, IN_MEDIACAO_SEMIPRESENCIAL, IN_MEDIACAO_EAD,
      IN_ESPECIAL_EXCLUSIVA, IN_REGULAR, IN_EJA, IN_PROFISSIONALIZANTE,
      IN_COMUM_CRECHE, IN_COMUM_PRE, IN_COMUM_FUND_AI, IN_COMUM_FUND_AF, IN_COMUM_MEDIO_MEDIO, IN_COMUM_MEDIO_INTEGRADO,
      IN_COMUM_MEDIO_FIC, IN_COMUM_MEDIO_NORMAL,
      IN_ESP_EXCLUSIVA_CRECHE, IN_ESP_EXCLUSIVA_PRE, IN_ESP_EXCLUSIVA_FUND_AI, IN_ESP_EXCLUSIVA_FUND_AF, IN_ESP_EXCLUSIVA_MEDIO_MEDIO,
      IN_ESP_EXCLUSIVA_MEDIO_INTEGR, IN_ESP_EXCLUSIVA_MEDIO_FIC, IN_ESP_EXCLUSIVA_MEDIO_NORMAL,
      IN_COMUM_EJA_FUND, IN_COMUM_EJA_MEDIO, IN_COMUM_EJA_PROF,
      IN_ESP_EXCLUSIVA_EJA_FUND, IN_ESP_EXCLUSIVA_EJA_MEDIO, IN_ESP_EXCLUSIVA_EJA_PROF,
      IN_COMUM_PROF, IN_ESP_EXCLUSIVA_PROF
  )
  FROM '/data/Tabela_Escolas.csv'
  DELIMITER ';'
  CSV HEADER
  ENCODING 'UTF8';

  -- =================================================================
  -- Índices para otimizar consultas comuns
  -- =================================================================

  CREATE INDEX IF NOT EXISTS idx_censo_escolas_co_entidade
      ON clean.censo_escolas (CO_ENTIDADE);

  -- (Opcional, mas útil) Índice para filtros por UF e município
  CREATE INDEX IF NOT EXISTS idx_censo_escolas_uf_municipio
      ON clean.censo_escolas (SG_UF, CO_MUNICIPIO);

  -- (Opcional) Se for usar busca por localização (latitude/longitude), considere um índice GiST depois de criar a coluna geometry
  ALTER TABLE clean.censo_escolas ADD COLUMN geometry geometry(Point, 4674);
  UPDATE clean.censo_escolas SET geometry = ST_SetSRID(ST_MakePoint(LONGITUDE, LATITUDE),4674 );
  CREATE INDEX idx_censo_escolas_geom ON clean.censo_escolas USING GIST (geometry);

COMMIT;
